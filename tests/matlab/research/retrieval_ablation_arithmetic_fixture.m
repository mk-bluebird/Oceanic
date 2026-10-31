% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Synthetic arithmetic-conformance fixture for
% retrieval_ablation_contrasts.m. Tests known contrast values under
% caller-supplied scores. Does not measure retrieval.
%
% Run from a directory on the MATLAB path where the calculator is present:
%   run_retrieval_ablation_arithmetic_fixture()

function summary = run_retrieval_ablation_arithmetic_fixture()
    failures = 0;
    total = 0;

    function check(name, cond)
        total = total + 1;
        if ~cond
            failures = failures + 1;
            fprintf('FAIL\t%s\n', name);
        else
            fprintf('PASS\t%s\n', name);
        end
    end

    % Case 1: exact four-condition scores, higher-is-better.
    scores = [0.40 0.50 0.60 0.80;
              0.50 0.60 0.70 0.90];
    before = scores;
    out = retrieval_ablation_contrasts(scores, ...
        'Synthetic performance', 'higher_is_better');
    check('baseline_ok', out.ok);
    check('nonmutation', isequal(scores, before));
    expected = [0.10 0.20 0.20 0.30 0.10];
    got = [out.value.summaries.mean_difference];
    check('contrast_means', max(abs(got - expected)) < 1e-12);
    check('per_row_size', size(out.value.per_row_contrasts, 2) == 5);
    check('interaction_equals_D_minus_C_minus_B_plus_A', ...
        abs(mean(scores(:,4)-scores(:,3)-scores(:,2)+scores(:,1)) ...
            - out.value.summaries(5).mean_difference) < 1e-12);

    % Case 2: determinism.
    out2 = retrieval_ablation_contrasts(scores, ...
        'Synthetic performance', 'higher_is_better');
    check('determinism', isequaln(out, out2));

    % Case 3: lower-is-better does not alter contrast arithmetic.
    lo = retrieval_ablation_contrasts(scores, ...
        'Synthetic performance', 'lower_is_better');
    check('direction_does_not_transform', ...
        max(abs([lo.value.summaries.mean_difference] - expected)) < 1e-12);

    % Case 4: NaN in one condition — paired missingness honored.
    miss = scores; miss(2,4) = NaN;
    mo = retrieval_ablation_contrasts(miss, ...
        'Synthetic performance', 'higher_is_better');
    check('paired_missingness_method_plain_full', ...
        mo.value.summaries(1).available_row_count == 2);
    check('paired_missingness_interaction_one_row', ...
        mo.value.summaries(5).available_row_count == 1);

    % Case 5: invalid shape rejected.
    bad = retrieval_ablation_contrasts([1 2 3], ...
        'Synthetic performance', 'higher_is_better');
    check('invalid_shape_code', ...
        ~bad.ok && strcmp(bad.error.code, 'E_SCORES'));

    % Case 6: invalid direction rejected.
    bad2 = retrieval_ablation_contrasts(scores, ...
        'Synthetic performance', 'up_is_good');
    check('invalid_direction_code', ...
        ~bad2.ok && strcmp(bad2.error.code, 'E_DIRECTION'));

    summary = struct( ...
        'status', 'synthetic_arithmetic_conformance_only', ...
        'total', total, 'failures', failures, ...
        'retrieval_measured', false, ...
        'ecological_validation_established', false, ...
        'attribution', 'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7');

    if failures > 0
        error('RetrievalAblationArithmetic:Failures', ...
            '%d of %d arithmetic-conformance checks failed.', failures, total);
    end
end
