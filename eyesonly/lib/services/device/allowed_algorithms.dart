

/// The default public key algorithm to use for device registration and challenge.
///
/// This is the asymmetric key algorithm used to generate device key pairs (e.g., X25519 for ECDH key exchange).
/// It determines the type of public/private key stored on the device and sent to the server during registration.
const String defaultPublicKeyAlgorithm = 'x25519';


/// List of allowed public key algorithms for device authentication challenge.
///
/// These are the asymmetric algorithms allowed for device key pairs.
const List<String> allowedPublicKeyAlgorithms = [
  defaultPublicKeyAlgorithm,
];



/// The default challenge (encryption) algorithm to use for device authentication.
///
/// This describes the full protocol used for the device authentication challenge, including key exchange,
/// key derivation, and symmetric encryption (e.g., 'x25519-hkdf-xchacha20poly1305' means X25519 for ECDH, HKDF for key derivation, and XChaCha20-Poly1305 for encryption).
/// The challenge algorithm may differ from the public key algorithm, as it describes the entire process, not just the key type.
const String defaultDeviceChallengeAlgorithm = 'x25519-hkdf-xchacha20poly1305';


/// List of allowed challenge (encryption) algorithms for device authentication.
///
/// These algorithms describe the full protocol for the device authentication challenge.
const List<String> allowedDeviceChallengeAlgorithms = [
  defaultDeviceChallengeAlgorithm,
];