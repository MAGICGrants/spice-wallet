// The address book store lives in wallet-core (wallet_domain), shared with
// Skylight; kept under this path so call sites are unchanged.
export 'package:wallet_domain/wallet_domain.dart'
    show readEncodedContacts, writeEncodedContacts, clearContacts;
