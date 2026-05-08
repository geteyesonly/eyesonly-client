/// Contains the HKDF info string used for device authentication key derivation.
/// Both client and server must use this exact value.
library;

const String deviceAuthHkdfInfo = 'eyesonly-device-auth-challenge-v1';
