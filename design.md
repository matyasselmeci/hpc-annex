9.8.0 Annex [Retro] HTCondor Usage Scheme
-----------------------------------------

The original design for the HPC Annex minimized what the AP admin(s) would
have to do in part to avoid administrative overheads, and in part thinking
that such a design would be more plausibly useful outside of the one place
where the PEP goal required that the HPC annex software work.

The original design used a separate HPC annex central manager for the
OSG Connect deployment, we (the developers) would deploy the CM via
tiger.  Jobs targeting an annex would use per-user flocking to get to
that CM.  This required that the user have a token for that CM in
`~/.condor/tokens.d`; we would write a small script to create and
deploy such a token for all existing accounts, and then expect the
OSG Connect admins to handle populating it for new accounts.

Such a token could also be used for connecting the pilot jobs on the
HPC systems to the annex CM.

However, per-user flocking only works for one user at a time, as
best we can tell, so administrative-level flocking will have to be
used until this can be fixed.

ToddT felt that asking the OSG connect admins to create and distribute
a token for every new user was too much.  Instead, the `htcondor` CLI
should generate a new (temporary) token every time it needed one.  This
has the advantage of making it easy to replace the token signing key,
because the old tokens don't need to be explicitly invalidated or
replaced.  Since per-user flocking no longer required a token, this
became plausible.  In practice, creating the token is probably only
mandatory for `htcondor annex create`, because it needs to be copied
to the pilot job.  Otherwise, the `htcondor` CLI doesn't ever actually
write to the collector; SSL-secured anonymous `READ` access is
perfectly sufficient.

For lack of a better way to handle it (see below), the HPC annex uses
the `PASSWORD` method to enable remote administration (shutdown).

Further Design Refinements
--------------------------

The general idea, again, is that the AP admin shouldn't have to know or do
anything if the user wants to bring their own resource.

- Fix per-user flocking so that we don't need to set up global flocking.
  This will probably involve
  - implementing session invalidation for per-user flock targets
  - and not caching the same session/daemon client object for different owners.
  
  I don't know how this would interact with the absence of a long-lived token
  on the AP, since we're generating new ones as we need them.  Perhaps the
  next point could be used to obtain such a token on demand?
- Allow startd remote administration capability to be retrieved by the
  same `AuthenticatedIdentity` that advertised it; this will eliminate the
  need to use PASSWORD (and maintain a per-user private password file) for
  administration.
- Implement token request forwarding, so that we don't have to have the same
  `TRUST_DOMAIN` on the APs and the annex CM.  This will also allow us to
  use the `TRUST_DOMAIN` in all cases in the job transforms used to control
  flocking, which will simplify administration further.

Anticipated Future Design
-------------------------

ToddT anticipates having the startds report directly to the AP from which
the annex was requested.  This should eliminate the need for someone to
maintain an annex CM, but it's not clear that simply querying the schedd
for the startd as if it were a collector will work.
