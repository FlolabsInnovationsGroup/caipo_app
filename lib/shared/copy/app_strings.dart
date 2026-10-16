/// User-facing copy in one place so it can be translated later.
abstract final class AppStrings {
  static const appName = 'CAIPO';
  static const dashboard = 'Dashboard';
  static const conversation = 'Conversation';
  static const library = 'Library';
  static const settings = 'Settings';
  static const notifications = 'Notifications';
  static const diagnostics = 'Diagnostics';
  static const pair = 'Pair';
  static const refresh = 'Refresh';
  static const dismiss = 'Dismiss';
  static const retry = 'Retry';
  static const cancel = 'Cancel';
  static const endSession = 'End session';
  static const talkToAi = 'Talk to AI';
  static const capture = 'Capture';
  static const recordVideo = 'Record video';
  static const liveView = 'Live view';
  static const needsWifi = 'Needs WiFi';
  static const uploadNow = 'Upload now';
  static const hotspotHint = 'Turn on your hotspot when you are outside and want to use the camera.';
  static const notSent = 'Not sent';
  static const wifiNetworks = 'CAIPO WiFi networks';
  static const phoneHotspot = 'My phone hotspot';
  static const startingCamera = 'Starting camera...';
  static const cameraBoot = 'The camera can take 5–15 seconds to start.';
  static const streamOff = 'Live streaming is proposed and turned off.';
  static const streamStopped = 'The camera stopped the stream.';
  static const localNetworkAsk = 'CAIPO needs the local network to reach the camera.';
  static const led = 'LED';
  static const gestures = 'Gestures';
  static const firmwareUpdate = 'Firmware update';
  static const needsDeviceSupport = 'Needs device support';
  static const pairCaipo = 'Pair CAIPO';
  static const playReply = 'Play reply';
  static const replayLastAnswer = 'Replay last answer';
  static const heard = 'Heard';
  static const searchConversation = 'Search conversation';
  static const delete = 'Delete';
  static const deleteAll = 'Delete all';
  static const deleteOneTitle = 'Delete this message?';
  static const deleteAllTitle = 'Delete the whole conversation on this phone?';
  static const noMessages = 'No messages yet. Talk to AI after CAIPO is connected.';
  static const noSearchHits = 'No messages match that search.';
  static const signOut = 'Sign out';
  static const autoLock = 'Auto-lock';
  static const autoLockHelp = 'Lock the app after this many minutes of no use. From 1 to 30. Default is 15.';
  static const autoConnect = 'Auto-connect';
  static const autoConnectHelp = 'Reconnect the last paired device when the app opens.';
  static const device = 'Device';
  static const account = 'Account';
  static const aiVoice = 'AI voice';
  static const aiLanguage = 'AI language';
  static const localOnly = 'Stored on this phone. The mock backend does not use it, and the live FloBrain fields are not confirmed.';
  static const voiceLanguageLocal =
      'Stored on this phone. The FloBrain preferences schema does not define voice or language.';
  static const biometricUnlock = 'Biometric unlock';
  static const biometricHelp = 'Optional. After auto-lock, unlock with biometrics. Password sign-in stays available.';
  static const exportData = 'Export my data';
  static const deleteLocalData = 'Delete all local data';
  static const deleteLocalHelp =
      'Removes conversation, media, saved Wi-Fi, and the keys on this phone, then signs out. This does not call FloBrain.';
  static const advancedAi = 'Advanced AI';
  static const sendImage = 'Send an image';
  static const sendVideo = 'Send a video';
  static const systemPrompt = 'Custom system prompt';
  static const offlineAi = 'Offline AI';
  static const about = 'About';
  static const bleContract = 'BLE contract';
  static const currentMode = 'Mode';
  static const renameDevice = 'Rename device';
  static const clearCache = 'Clear transfer cache';
  static const changePassword = 'Change password';
  static const currentPassword = 'Current password';
  static const newPassword = 'New password';
  static const deleteAccount = 'Delete account';
  static const deleteAccountTitle = 'Delete this account?';
  static const save = 'Save';
  static const exportLogs = 'Export logs';
  static const bugReport = 'Send a bug report';
  static const help = 'Help';
  static const connectionLogs = 'Connection log';
  static const errorHistory = 'Error history';
  static const liveLink = 'Live link';
  static const noLogs = 'No log lines yet.';
  static const noErrors = 'No errors recorded.';
  static const rssiUnknown = 'RSSI is not reported.';
  static const speedUnknown = 'No transfer has been timed yet.';
  static const chargingUnknown = 'Charging is not reported by the device yet.';
  static const videoEmpty = 'No video. The device has not sent any, and picture-in-picture waits on the media contract.';
  static const photosEmpty = 'No photos. Image preview waits on the device image format.';
  static const imagePreview = 'Image preview waits on the device image format.';
  static const audioEmpty = 'No audio clips yet. A finished Talk to AI turn saves one here.';
  static const share = 'Share';
  static const playbackSpeed = 'Playback speed';
  static const replyText = 'Reply text';
  static const transcriptSyncNote = 'Word-level sync is not available. This is the reply text, not timed captions.';
  static const allowNotifications = 'Allow notifications';
  static const lowBatteryPref = 'Low battery';
  static const linkLostPref = 'Connection lost';
  static const transferDonePref = 'Transfer done';
  static const notificationList = 'Recent';
  static const noNotifications = 'No notifications yet.';
  static const lowBatteryTitle = 'Low battery';
  static const linkLostTitle = 'Connection lost';
  static const transferDoneTitle = 'Transfer done';
  static const onboardingTitle = 'CAIPO';
  static const onboardingNext = 'Next';
  static const onboardingStart = 'Continue';
  static const bluetooth = 'Bluetooth';
  static const openSettings = 'Open settings';
  static const forget = 'Forget';
  static const noDevices = 'No devices yet. Refresh to scan, or reconnect a device you have paired before.';
  static const lastMedia = 'Last media';
  static const noMedia = 'Nothing saved yet.';
  static const battery = 'Battery';
  static const state = 'State';
  static const notConnected = 'Not connected';
  static const connected = 'Connected';

  static String minutes(int value) => '$value min';

  static String lowBatteryBody(int percent) => 'CAIPO battery is $percent%.';

  static const linkLostBody = 'The link to CAIPO dropped.';

  static const transferDoneBody = 'The reply transfer finished.';

  static const onboardingPages = [
    'CAIPO pairs with the glasses and sends your voice to FloBrain.',
    'Bluetooth permission is asked when you pair, not before.',
    'Pair from the dashboard. This build can use the simulated device CAIPO-SIM.',
  ];

  static const faq = [
    (question: 'How do I try the voice loop?', answer: 'Sign in, open Pair, refresh, and connect to CAIPO-SIM. Talk to AI on the dashboard shows the states. Play reply uses the phone speaker.'),
    (question: 'Why is Capture off?', answer: 'Capture, the LED, gestures, and firmware update need device commands that are not in the BLE contract yet.'),
    (question: 'Where is video?', answer: 'The library only shows files the device actually sent. Video and picture-in-picture wait on the Wi-Fi media contract.'),
  ];
}
