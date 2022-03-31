  #### How to determine your PROJECT at various machines

  - `gsissh stampede2 /usr/local/etc/taccinfo`
  - `gsissh expanse 'module load sdsc; expanse-client user'`

  #### Installing HPC Annex on OSG Connect (for the demo)

  - `git clone https://github.com/htcondor/htcondor.git`
  - (check out the appropriate branch)
  - install token in `~/.condor/tokens.d`
    ```
    condor_token_create -identity tlmiller@annex.osgdev.chtc.io \
         -authz READ \
         -authz ADVERTISE_STARTD \
         -authz ADVERTISE_MASTER \
         -authz ADVERTISE_SCHEDD \
     > tlmiller@annex.osgdev.chtc.io
  - mkdir `~/.hpc-annex`  (should this become `~/.condor/hpc-annex`?)
  - set `LIBEXEC` in `~/.condor/user_config` because the system install
    of HTCondor doesn't have HPC Annex yet, to `~/condor/install/libexec`,
    which contains an `annex` symlink pointing at `src/condor_scripts/annex`.
  - `src/condor_tools/htcondor` invokes properly...

#### Extra (Temporary) Annex CM configuration

```
# Harumph.
TRUST_DOMAIN = azaphrael.org

# Allow any pilot to whom we've given a token to advertise.
ALLOW_ADVERTISE_STARTD = *@$(TRUST_DOMAIN)
# Allow any user to whom we've given a token to flock.
ALLOW_ADVERTISE_SCHEDD = *@$(TRUST_DOMAIN)
# Allow ourselves and the pilots to advertise masters.
ALLOW_ADVERTISE_MASTER = $(ALLOW_ADVERTISE_STARTD) $(ALLOW_ADMINISTRATOR)

# Enable SSL (unnecessary but maybe convenient).
# AUTH_SSL_SERVER_CERTFILE = /etc/grid-security/condor-le/tls.crt
# AUTH_SSL_SERVER_KEYFILE = /etc/grid-security/condor-le/tls.key
```

#### Extra (Testing) AP configuration

```
# Allow us to connect using SSL to the collector.
SEC_DEFAULT_AUTHENTICATION_METHODS = FS, IDTOKENS, SSL
# AUTH_SSL_CLIENT_CAFILE = /etc/ssl/certs/ca-certificates.crt

# Because per-user flocking doesn't actually work.  I don't know why
# MIN_FLOCK_LEVEL is, in practice, required.
FLOCK_TO = htcondor-cm-hpcannex.osgdev.chtc.io
MIN_FLOCK_LEVEL = 1

# IDTOKENS assumes that if we share a trust domain, we share our default
# signing keys; this is probably fine, except that it tries the shared-secret
# fallback method BEFORE trying to use a token.
SEC_TOKEN_POOL_SIGNING_KEY_FILE = $(LOCAL)/passwords.d/hpcannex-key
```
