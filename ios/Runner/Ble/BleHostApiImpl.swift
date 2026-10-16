import Flutter
import Foundation
import UIKit

final class BleHostApiImpl: BleHostApi {
    private let manager = CaipoBleManager.shared
    private let flutterApi: BleFlutterApi

    init(flutterApi: BleFlutterApi) {
        self.flutterApi = flutterApi
        manager.flutterState = { [weak self] state in
            self?.emit { try await self?.flutterApi.onBluetoothStateChanged(state: state) }
        }
        manager.flutterDiscovered = { [weak self] uuid, name, rssi, services in
            let peripheral = BlePeripheral(uuid: uuid, name: name, rssi: Int64(rssi), serviceUuids: services)
            self?.emit { try await self?.flutterApi.onPeripheralDiscovered(peripheral: peripheral) }
        }
        manager.flutterReady = { [weak self] uuid, services in
            let mapped = services.map { BleService(uuid: $0.uuid, characteristicUuids: $0.characteristics) }
            self?.emit { try await self?.flutterApi.onDeviceReady(peripheralUuid: uuid, services: mapped) }
        }
        manager.flutterDisconnected = { [weak self] uuid, error in
            self?.emit { try await self?.flutterApi.onPeripheralDisconnected(peripheralUuid: uuid, error: error) }
        }
        manager.flutterValue = { [weak self] uuid, service, characteristic, value in
            self?.emit {
                try await self?.flutterApi.onCharacteristicValueUpdated(
                    peripheralUuid: uuid,
                    serviceUuid: service,
                    characteristicUuid: characteristic,
                    value: value
                )
            }
        }
        manager.flutterRssi = { [weak self] uuid, rssi in
            self?.emit { try await self?.flutterApi.onRssiUpdate(peripheralUuid: uuid, rssi: Int64(rssi)) }
        }
        manager.flutterRestored = { [weak self] ids in
            self?.emit { try await self?.flutterApi.onStateRestored(peripheralUuids: ids) }
        }
    }

    func startScan(timeoutSeconds: Int64, serviceUuids: [String]) throws {
        manager.startScan(timeout: Int(timeoutSeconds), serviceUuids: serviceUuids)
    }

    func stopScan() throws { manager.stopScan() }

    func manageDevice(uuid: String, requiresBond: Bool) throws { manager.connect(uuid: uuid) }

    func unmanageDevice(uuid: String) throws { manager.disconnect(uuid: uuid) }

    /// iOS cannot start SMP bonding. The firmware requires encryption on the
    /// characteristics, and CoreBluetooth shows the pairing dialog on the
    /// first access. Returning true keeps Dart from treating the missing API
    /// as a bond failure.
    func requestBond(uuid: String) async throws -> Bool { true }

    func readCharacteristic(peripheralUuid: String, serviceUuid: String, characteristicUuid: String) async throws -> FlutterStandardTypedData {
        try await withCheckedThrowingContinuation { continuation in
            manager.read(uuid: peripheralUuid, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid) { result in
                continuation.resume(with: result)
            }
        }
    }

    func writeCharacteristic(peripheralUuid: String, serviceUuid: String, characteristicUuid: String, data: FlutterStandardTypedData) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.write(uuid: peripheralUuid, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid, data: data) { result in
                continuation.resume(with: result)
            }
        }
    }

    func subscribeCharacteristic(peripheralUuid: String, serviceUuid: String, characteristicUuid: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.subscribe(uuid: peripheralUuid, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid) { result in
                continuation.resume(with: result)
            }
        }
    }

    func unsubscribeCharacteristic(peripheralUuid: String, serviceUuid: String, characteristicUuid: String) throws {
        manager.unsubscribe(uuid: peripheralUuid, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid)
    }

    func getBluetoothState() throws -> String { manager.bluetoothState() }

    func enableBluetooth() async throws -> Bool { manager.bluetoothState() == "on" }

    func isPeripheralConnected(uuid: String) throws -> Bool { manager.isConnected(uuid: uuid) }

    func maximumWriteLength(peripheralUuid: String) async throws -> Int64 {
        Int64(manager.maximumWriteLength(uuid: peripheralUuid))
    }

    func startRssiStreaming(uuid: String) throws { manager.startRssi(uuid: uuid) }

    func stopRssiStreaming(uuid: String) throws { manager.stopRssi() }

    func openBluetoothSettings() throws {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }

    private func emit(_ work: @escaping () async throws -> Void) {
        Task { @MainActor in
            try? await work()
        }
    }
}
