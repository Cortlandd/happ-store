nacl_factory.instantiate(function(nacl) {
    var serverPk = nacl.from_hex(serverPk);
    var keys = nacl.crypto_sign_keypair();

    // String -> { publicKey : Hex, signature : Hex }
    function sign(message_) {
        var message = nacl.encode_utf8(message_);
        return {
            "publicKey" : nacl.to_hex(keys.signPk),
            "signature" : nacl.to_hex(nacl.crypto_sign(message, keys.signSk))
        };
    }

    // Hex -> Maybe String
    function verify(signature_) {
        try {
            var signature = nacl.from_hex(signature_);
            var message = nacl.crypto_sign_open(signature, serverPk);
            if (message === null) {
                return null;
            } else {
                return nacl.decode_utf8(message);
            }
        } catch (e) {
            console.error("Decoding error:", e);
            return null;
        }
    }


    var app = Elm.Main.fullscreen(
    );

    // sha256
    app.ports.makeSHASession.subscribe(function(xs) {
        var shaObj = new jsSHA("SHA-512", "TEXT");
        shaObj.update(xs.input);
        var hash = shaObj.getHash("B64");
        app.ports.madeSHASession.send({
            threadId : xs.threadId,
            output   : hash
        });
    });

    app.ports.askInitNonce.subscribe(function(threadId) {
        app.ports.getInitNonce.send({
            seed1    : Math.floor(Math.random() * 0xFFFFFFFF),
            seed2    : Math.floor(Math.random() * 0xFFFFFFFF),
            threadId : threadId
        });
    });
});
