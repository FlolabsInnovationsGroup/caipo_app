/// Proposed firmware and backend behavior. Every flag is off unless the
/// build passes the matching `--dart-define`.
///
/// Off means the app does not call the endpoint or write the opcode.
const bool kProposedSpeech = bool.fromEnvironment('PROPOSED_SPEECH', defaultValue: false);
const bool kProposedMedia = bool.fromEnvironment('PROPOSED_MEDIA', defaultValue: false);
const bool kProposedCommands = bool.fromEnvironment('PROPOSED_COMMANDS', defaultValue: false);
const bool kProposedWifi = bool.fromEnvironment('PROPOSED_WIFI', defaultValue: false);
const bool kProposedStream = bool.fromEnvironment('PROPOSED_STREAM', defaultValue: false);
