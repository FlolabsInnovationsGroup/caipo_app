import CoreBluetooth
import Flutter
import Foundation

/// CoreBluetooth central adapted from the shape of OMI's BLE manager (MIT).
/// Restore identifier and device identity are CAIPO's, not OMI's.
final class CaipoBleManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = CaipoBleManager()
    static let restoreIdentifier = "com.flolabs.caipo.ble"

    var flutterReady: ((String, [(uuid: String, characteristics: [String])]) -> Void)?
    var flutterDisconnected: ((String, String?) -> Void)?
    var flutterDiscovered: ((String, String, Int, [String]) -> Void)?
    var flutterState: ((String) -> Void)?
    var flutterValue: ((String, String, String, FlutterStandardTypedData) -> Void)?
    var flutterRssi: ((String, Int) -> Void)?
    var flutterRestored: (([String]) -> Void)?

    private var central: CBCentralManager!
    private var peripherals: [String: CBPeripheral] = [:]
    private var pendingScan: (timeout: Int, services: [String])?
    private var scanTimer: Timer?
    private var isScanning = false
    private var readyNotified = Set<String>()
    private var manual = Set<String>()
    private var readCompletions: [String: (Result<FlutterStandardTypedData, Error>) -> Void] = [:]
    private var writeCompletions: [String: (Result<Void, Error>) -> Void] = [:]
    private var subscribeCompletions: [String: (Result<Void, Error>) -> Void] = [:]
    private var pendingDiscovery: [String: Int] = [:]
    private var rssiTimer: Timer?
    private var rssiUuid: String?

    private override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: CaipoBleManager.restoreIdentifier]
        )
    }

    func bluetoothState() -> String {
        switch central.state {
        case .poweredOn: return "on"
        case .poweredOff: return "off"
        case .unauthorized: return "unauthorized"
        case .unsupported: return "unsupported"
        case .resetting: return "turning_off"
        default: return "unknown"
        }
    }

    func startScan(timeout: Int, serviceUuids: [String]) {
        guard central.state == .poweredOn else {
            pendingScan = (timeout, serviceUuids)
            flutterState?(bluetoothState())
            return
        }
        pendingScan = nil
        let filters = serviceUuids.isEmpty ? nil : serviceUuids.map { CBUUID(string: $0) }
        isScanning = true
        central.scanForPeripherals(withServices: filters, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        scanTimer?.invalidate()
        if timeout > 0 {
            scanTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeout), repeats: false) { [weak self] _ in
                self?.stopScan()
            }
        }
    }

    func stopScan() {
        pendingScan = nil
        guard isScanning else { return }
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
        central.stopScan()
    }

    func connect(uuid: String) {
        manual.remove(uuid)
        readyNotified.remove(uuid)
        let peripheral: CBPeripheral?
        if let known = peripherals[uuid] {
            peripheral = known
        } else if let id = UUID(uuidString: uuid) {
            peripheral = central.retrievePeripherals(withIdentifiers: [id]).first
        } else {
            peripheral = nil
        }
        guard let peripheral else {
            flutterDisconnected?(uuid, "not_found")
            return
        }
        peripheral.delegate = self
        peripherals[uuid] = peripheral
        if peripheral.state == .connected {
            peripheral.discoverServices(nil)
        } else {
            central.connect(peripheral, options: nil)
        }
    }

    func disconnect(uuid: String) {
        manual.insert(uuid)
        guard let peripheral = peripherals[uuid] else { return }
        central.cancelPeripheralConnection(peripheral)
    }

    func isConnected(uuid: String) -> Bool {
        peripherals[uuid]?.state == .connected
    }

    /// With-response write size. iOS has no MTU request; this is the value CoreBluetooth reports.
    func maximumWriteLength(uuid: String) -> Int {
        guard let peripheral = peripherals[uuid] else { return 20 }
        return max(peripheral.maximumWriteValueLength(for: .withResponse), 20)
    }

    func read(uuid: String, serviceUuid: String, characteristicUuid: String, completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
        guard let characteristic = find(uuid: uuid, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid),
              let peripheral = peripherals[uuid] else {
            completion(.failure(error("Characteristic not found")))
            return
        }
        readCompletions[key(uuid, serviceUuid, characteristicUuid)] = completion
        peripheral.readValue(for: characteristic)
    }

    func write(uuid: String, serviceUuid: String, characteristicUuid: String, data: FlutterStandardTypedData, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let characteristic = find(uuid: uuid, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid),
              let peripheral = peripherals[uuid] else {
            completion(.failure(error("Characteristic not found")))
            return
        }
        writeCompletions[key(uuid, serviceUuid, characteristicUuid)] = completion
        peripheral.writeValue(data.data, for: characteristic, type: .withResponse)
    }

    func subscribe(uuid: String, serviceUuid: String, characteristicUuid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let characteristic = find(uuid: uuid, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid),
              let peripheral = peripherals[uuid] else {
            completion(.failure(error("Characteristic not found")))
            return
        }
        subscribeCompletions[key(uuid, serviceUuid, characteristicUuid)] = completion
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func unsubscribe(uuid: String, serviceUuid: String, characteristicUuid: String) {
        guard let characteristic = find(uuid: uuid, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid),
              let peripheral = peripherals[uuid] else { return }
        peripheral.setNotifyValue(false, for: characteristic)
    }

    func startRssi(uuid: String) {
        rssiUuid = uuid
        rssiTimer?.invalidate()
        rssiTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let id = self.rssiUuid, let peripheral = self.peripherals[id] else { return }
            peripheral.readRSSI()
        }
    }

    func stopRssi() {
        rssiUuid = nil
        rssiTimer?.invalidate()
        rssiTimer = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        flutterState?(bluetoothState())
        if central.state == .poweredOn, let pending = pendingScan {
            startScan(timeout: pending.timeout, serviceUuids: pending.services)
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        var ids: [String] = []
        for peripheral in restored {
            let id = peripheral.identifier.uuidString
            peripheral.delegate = self
            peripherals[id] = peripheral
            ids.append(id)
            if peripheral.state == .connected {
                peripheral.discoverServices(nil)
            }
        }
        flutterRestored?(ids)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let id = peripheral.identifier.uuidString
        peripherals[id] = peripheral
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map { $0.uuidString } ?? []
        flutterDiscovered?(id, name, RSSI.intValue, services)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        pendingDiscovery[peripheral.identifier.uuidString] = 0
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        flutterDisconnected?(peripheral.identifier.uuidString, "timeout")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier.uuidString
        let reason = manual.contains(id) ? "cancelled" : "link_lost"
        manual.remove(id)
        readyNotified.remove(id)
        flutterDisconnected?(id, reason)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let id = peripheral.identifier.uuidString
        if error != nil {
            flutterDisconnected?(id, "gatt_discovery_failed")
            return
        }
        let services = peripheral.services ?? []
        pendingDiscovery[id] = services.count
        if services.isEmpty {
            publishReady(peripheral)
            return
        }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let id = peripheral.identifier.uuidString
        pendingDiscovery[id] = max(0, (pendingDiscovery[id] ?? 1) - 1)
        if pendingDiscovery[id] == 0 {
            publishReady(peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let id = peripheral.identifier.uuidString
        let service = characteristic.service?.uuid.uuidString ?? ""
        let charId = characteristic.uuid.uuidString
        let key = key(id, service, charId)
        if let completion = readCompletions.removeValue(forKey: key) {
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(FlutterStandardTypedData(bytes: characteristic.value ?? Data())))
            }
            return
        }
        guard error == nil else { return }
        flutterValue?(id, service, charId, FlutterStandardTypedData(bytes: characteristic.value ?? Data()))
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let key = key(peripheral.identifier.uuidString, characteristic.service?.uuid.uuidString ?? "", characteristic.uuid.uuidString)
        guard let completion = writeCompletions.removeValue(forKey: key) else { return }
        if let error { completion(.failure(error)) } else { completion(.success(())) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let key = key(peripheral.identifier.uuidString, characteristic.service?.uuid.uuidString ?? "", characteristic.uuid.uuidString)
        guard let completion = subscribeCompletions.removeValue(forKey: key) else { return }
        if let error { completion(.failure(error)) } else { completion(.success(())) }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error == nil {
            flutterRssi?(peripheral.identifier.uuidString, RSSI.intValue)
        }
    }

    private func publishReady(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        guard readyNotified.insert(id).inserted else { return }
        let services = (peripheral.services ?? []).map { service in
            (uuid: service.uuid.uuidString, characteristics: (service.characteristics ?? []).map { $0.uuid.uuidString })
        }
        flutterReady?(id, services)
    }

    private func find(uuid: String, serviceUuid: String, characteristicUuid: String) -> CBCharacteristic? {
        guard let peripheral = peripherals[uuid] else { return nil }
        let serviceId = CBUUID(string: serviceUuid)
        let charId = CBUUID(string: characteristicUuid)
        return peripheral.services?.first { $0.uuid == serviceId }?.characteristics?.first { $0.uuid == charId }
    }

    private func key(_ uuid: String, _ service: String, _ characteristic: String) -> String {
        "\(uuid.lowercased()):\(service.lowercased()):\(characteristic.lowercased())"
    }

    private func error(_ message: String) -> NSError {
        NSError(domain: "CaipoBle", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
