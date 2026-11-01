function test_audit_flux_target_identifiability()
% Synthetic fluxes: [deposition, transportIn, cleanup, transportOut, loss].
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

H = [1,1,-1,-1,-1; 0,0,1,0,0];
truth = [30;5;10;8;2];
y = H*truth;
targetD = [1;0;0;0;0];

base = audit_flux_target_identifiability( ...
    H,y,eye(2),targetD,1e-10);
assert(base.observationRank == 2);
assert(~base.targetIdentifiableAtTolerance);

% Net deposition/transport/loss is identifiable without all five fluxes.
netTarget = [1;1;0;-1;-1];
net = audit_flux_target_identifiability( ...
    H,y,eye(2),netTarget,1e-10);
assert(net.targetIdentifiableAtTolerance);
assert(abs(net.targetEstimate-25) < 1e-10);

% Direct deposition observation identifies D while total rank is only 3.
H3 = [H;1,0,0,0,0];
identifiedD = audit_flux_target_identifiability( ...
    H3,H3*truth,eye(3),targetD,1e-10);
assert(identifiedD.observationRank == 3);
assert(identifiedD.targetIdentifiableAtTolerance);
assert(~identifiedD.fullFluxVectorIdentifiableAtTolerance);
assert(abs(identifiedD.targetEstimate-30) < 1e-10);

% Repetition of an existing observation does not resolve the ambiguity.
repeated = [H;H(1,:)];
stillUnknown = audit_flux_target_identifiability( ...
    repeated,repeated*truth,eye(3),targetD,1e-10);
assert(~stillUnknown.targetIdentifiableAtTolerance);
end
