---------------------- MODULE TemporalCapability ----------------------
EXTENDS Integers, FiniteSets

CONSTANTS
  Caps,
  NotBefore,
  ExpiresAt,
  MaxTime,
  MaxUncertainty,
  MaxEvents

ASSUME
  /\ IsFiniteSet(Caps)
  /\ Caps # {}
  /\ NotBefore \in Nat
  /\ ExpiresAt \in Nat
  /\ NotBefore < ExpiresAt
  /\ MaxTime \in Nat
  /\ ExpiresAt <= MaxTime
  /\ MaxUncertainty \in 0..MaxTime
  /\ MaxEvents \in Nat

VARIABLES
  trueTime,
  clockLo,
  clockHi,
  consent,
  logicalClock,
  uses

vars ==
  <<trueTime, clockLo, clockHi, consent, logicalClock, uses>>

Init ==
  /\ trueTime = 0
  /\ clockLo = 0
  /\ clockHi = MaxUncertainty
  /\ consent = Caps
  /\ logicalClock = 0
  /\ uses = {}

BoundUsable ==
  /\ clockLo <= clockHi
  /\ clockHi - clockLo <= MaxUncertainty

Enabled ==
  {c \in consent :
    /\ BoundUsable
    /\ clockLo >= NotBefore
    /\ clockHi < ExpiresAt}

Tick ==
  /\ trueTime < MaxTime
  /\ trueTime' = trueTime + 1
  /\ clockHi' = IF clockHi < MaxTime THEN clockHi + 1 ELSE MaxTime
  /\ UNCHANGED <<clockLo, consent, logicalClock, uses>>

SampleClock ==
  \E lo \in 0..trueTime, hi \in trueTime..MaxTime :
    /\ hi - lo <= MaxUncertainty
    /\ clockLo' = lo
    /\ clockHi' = hi
    /\ UNCHANGED <<trueTime, consent, logicalClock, uses>>

Withdraw(c) ==
  /\ c \in consent
  /\ consent' = consent \ {c}
  /\ UNCHANGED <<trueTime, clockLo, clockHi, logicalClock, uses>>

Use(c) ==
  /\ c \in Enabled
  /\ logicalClock < MaxEvents
  /\ logicalClock' = logicalClock + 1
  /\ uses' = uses \cup {
       [cap |-> c,
        seq |-> logicalClock + 1,
        lo |-> clockLo,
        hi |-> clockHi,
        at |-> trueTime]
     }
  /\ UNCHANGED <<trueTime, clockLo, clockHi, consent>>

Next ==
  \/ Tick
  \/ SampleClock
  \/ \E c \in Caps : Withdraw(c)
  \/ \E c \in Caps : Use(c)

TypeOK ==
  /\ trueTime \in 0..MaxTime
  /\ clockLo \in 0..MaxTime
  /\ clockHi \in 0..MaxTime
  /\ consent \subseteq Caps
  /\ logicalClock \in 0..MaxEvents
  /\ uses \subseteq [
       cap : Caps,
       seq : 1..MaxEvents,
       lo : 0..MaxTime,
       hi : 0..MaxTime,
       at : 0..MaxTime
     ]

ClockSound ==
  /\ clockLo <= trueTime
  /\ trueTime <= clockHi

EnabledWithinValidity ==
  \A c \in Enabled :
    /\ NotBefore <= trueTime
    /\ trueTime < ExpiresAt

UseEvidenceSafe ==
  \A u \in uses :
    /\ u.lo <= u.at
    /\ u.at <= u.hi
    /\ u.lo >= NotBefore
    /\ u.hi < ExpiresAt
    /\ NotBefore <= u.at
    /\ u.at < ExpiresAt

Spec ==
  Init /\ [][Next]_vars

=============================================================================
