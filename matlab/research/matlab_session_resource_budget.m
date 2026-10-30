function envelope = matlab_session_resource_budget(varargin)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit only; not verification, consent, or authorization.
%
% Call:
% envelope = matlab_session_resource_budget(config)
%
% config fields, exactly:
% installation_components: struct vector with name, bytes
% download_bytes: nonnegative finite double scalar
% staging_bytes: nonnegative finite double scalar
% scratch_bytes: nonnegative finite double scalar
% client_ram_bytes: nonnegative finite double scalar
% worker_ram_bytes: nonnegative finite double scalar, per worker
% worker_count: nonnegative integer double scalar
% arrays: struct vector with name, elements, bytes_per_element, live_copies
% disk_reserve_fraction: nonnegative finite double scalar
% ram_reserve_fraction: nonnegative finite double scalar
%
% Empty component and array struct vectors are allowed.
% All array allocations must be entered as aggregate simultaneously live
% payloads; worker replication is NOT automatically applied to arrays.
%
% No arguments runs synthetic self-tests.
% No filesystem reads/writes, network access, installation, or telemetry.
% Results are modeled budgets, not measured resource usage.

schema_version = '1.0.0';
module_version = '1.0.0';

try
    if nargin == 0
        value = self_tests();
    elseif nargin == 1
        value = evaluate(varargin{1});
    else
        error('SessionBudget:E_ARGUMENTS', ...
            'Supply one configuration, or no arguments for self-tests.');
    end
    envelope = struct('ok', true, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', value, ...
        'error', struct('code', '', 'message', ''));
catch exception
    prefix = 'SessionBudget:';
    if strncmp(exception.identifier, prefix, numel(prefix))
        code = exception.identifier(numel(prefix) + 1:end);
        message = exception.message;
    else
        code = 'E_INTERNAL';
        message = 'Unexpected internal failure; inspect locally.';
    end
    envelope = struct('ok', false, ...
        'schema_version', schema_version, ...
        'module_version', module_version, ...
        'value', [], ...
        'error', struct('code', code, 'message', message));
end
end

function result = evaluate(config)
required = {'installation_components', 'download_bytes', ...
    'staging_bytes', 'scratch_bytes', 'client_ram_bytes', ...
    'worker_ram_bytes', 'worker_count', 'arrays', ...
    'disk_reserve_fraction', 'ram_reserve_fraction'};

if ~isstruct(config) || ~isscalar(config) || ...
        ~isequal(sort(fieldnames(config)), sort(required(:)))
    error('SessionBudget:E_CONFIG', ...
        'Configuration must contain exactly the documented fields.');
end

scalar_fields = required(2:7);
scalar_fields = [scalar_fields, required(9:10)];
for j = 1:numel(scalar_fields)
    field = scalar_fields{j};
    check_number(config.(field), field, false);
end
if config.worker_count ~= floor(config.worker_count)
    error('SessionBudget:E_WORKER_COUNT', ...
        'worker_count must be a nonnegative integer.');
end

components = config.installation_components;
check_struct_vector(components, {'name', 'bytes'}, 'installation_components');
installed = 0;
for j = 1:numel(components)
    check_name(components(j).name);
    check_number(components(j).bytes, 'component bytes', false);
    installed = installed + components(j).bytes;
end

arrays = config.arrays;
check_struct_vector(arrays, ...
    {'name', 'elements', 'bytes_per_element', 'live_copies'}, 'arrays');
array_details = repmat(struct('name', '', 'modeled_bytes', 0), ...
    1, numel(arrays));
array_total = 0;

for j = 1:numel(arrays)
    check_name(arrays(j).name);
    check_number(arrays(j).elements, 'array elements', false);
    check_number(arrays(j).bytes_per_element, 'bytes per element', true);
    check_number(arrays(j).live_copies, 'live copies', false);

    if arrays(j).elements ~= floor(arrays(j).elements) || ...
            arrays(j).live_copies ~= floor(arrays(j).live_copies) || ...
            arrays(j).bytes_per_element ~= floor(arrays(j).bytes_per_element)
        error('SessionBudget:E_ARRAY_INTEGER', ...
            'Array element counts, byte widths, and copy counts must be integers.');
    end

    bytes = arrays(j).elements * arrays(j).bytes_per_element ...
        * arrays(j).live_copies;
    array_details(j).name = arrays(j).name;
    array_details(j).modeled_bytes = bytes;
    array_total = array_total + bytes;
end

peak_disk = installed + config.download_bytes ...
    + config.staging_bytes + config.scratch_bytes;
worker_total = config.worker_count * config.worker_ram_bytes;
modeled_ram = config.client_ram_bytes + worker_total + array_total;
disk_target = peak_disk * (1 + config.disk_reserve_fraction);
ram_target = modeled_ram * (1 + config.ram_reserve_fraction);

totals = [installed, array_total, peak_disk, worker_total, ...
    modeled_ram, disk_target, ram_target];
if any(isnan(totals) | isinf(totals)) || any(totals > flintmax)
    error('SessionBudget:E_NUMERIC_RANGE', ...
        'Budget exceeded finite exact-integer byte representation.');
end

result = struct();
result.status = 'planning_only';
result.installation_components = components;
result.array_details = array_details;
result.installed = units(installed);
result.download = units(config.download_bytes);
result.staging = units(config.staging_bytes);
result.scratch = units(config.scratch_bytes);
result.disk_peak_same_volume = units(peak_disk);
result.disk_target_with_reserve = units(disk_target);
result.client_ram = units(config.client_ram_bytes);
result.worker_ram_total = units(worker_total);
result.array_payload_total = units(array_total);
result.modeled_ram_total = units(modeled_ram);
result.ram_target_with_reserve = units(ram_target);
result.disk_reserve_fraction = config.disk_reserve_fraction;
result.ram_reserve_fraction = config.ram_reserve_fraction;
result.input_provenance = 'caller_supplied_not_verified';
result.actual_installation_measured = false;
result.actual_peak_ram_measured = false;
result.external_actions = 'none';
result.attribution = ...
    'bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7';
result.interpretation_limits = { ...
    'Installation components must not overlap.', ...
    'Disk peak assumes entered components coexist on one volume.', ...
    'Arrays represent aggregate simultaneously live payloads.', ...
    'Worker replication of arrays must be included by the caller.', ...
    'OS memory, array headers, fragmentation, and omitted temporaries are excluded.', ...
    'A reserve is a planning choice, not a vendor requirement.', ...
    'This module does not establish license or platform compatibility.'};
end

function value = units(bytes)
value = struct('bytes', bytes, ...
    'GB_decimal', bytes / 1e9, ...
    'GiB_binary', bytes / 2^30);
end

function check_number(value, label, strictly_positive)
if ~isa(value, 'double') || ~isreal(value) || ~isscalar(value) || ...
        isnan(value) || isinf(value) || value < 0 || ...
        (strictly_positive && value == 0) || value > flintmax
    error('SessionBudget:E_NUMBER', ...
        'Invalid finite nonnegative numeric input: %s.', label);
end
end

function check_name(value)
if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
    error('SessionBudget:E_NAME', ...
        'Component and array names must be nonempty character rows.');
end
end

function check_struct_vector(value, fields, label)
if ~isstruct(value) || ...
        ~(isvector(value) || isempty(value)) || ...
        ~isequal(sort(fieldnames(value)), sort(fields(:)))
    error('SessionBudget:E_STRUCTURE', ...
        'Invalid documented structure vector: %s.', label);
end
end

function result = self_tests()
config = struct();
config.installation_components = ...
    struct('name', 'Synthetic installed component', 'bytes', 1024);
config.download_bytes = 2048;
config.staging_bytes = 4096;
config.scratch_bytes = 8192;
config.client_ram_bytes = 1024;
config.worker_ram_bytes = 512;
config.worker_count = 2;
config.arrays = struct('name', 'Synthetic double matrix', ...
    'elements', 100, 'bytes_per_element', 8, 'live_copies', 2);
config.disk_reserve_fraction = 0.25;
config.ram_reserve_fraction = 0.5;

before = config;
a = matlab_session_resource_budget(config);
must(a.ok, 'baseline_success');
must(isequal(config, before), 'nonmutation');
must(a.value.disk_peak_same_volume.bytes == 15360, 'disk_sum');
must(a.value.array_payload_total.bytes == 1600, 'array_payload');
must(a.value.modeled_ram_total.bytes == 3648, 'ram_sum');
must(a.value.ram_target_with_reserve.bytes == 5472, 'ram_reserve');

b = matlab_session_resource_budget(config);
must(isequaln(a, b), 'determinism');

invalid = config;
invalid.worker_count = 0.5;
failure = matlab_session_resource_budget(invalid);
must(~failure.ok && strcmp(failure.error.code, 'E_WORKER_COUNT'), ...
    'worker_count_validation');

invalid = config;
invalid.arrays.elements = NaN;
failure = matlab_session_resource_budget(invalid);
must(~failure.ok && strcmp(failure.error.code, 'E_NUMBER'), ...
    'nonfinite_validation');

result = struct('status', 'synthetic_self_tests_passed', ...
    'field_measurement', 'not_performed', ...
    'coverage', {{'envelopes', 'disk_arithmetic', 'array_arithmetic', ...
    'ram_arithmetic', 'reserve', 'nonmutation', ...
    'determinism', 'invalid_workers', 'nonfinite_input'}});
end

function must(condition, name)
if ~condition
    error('SessionBudget:E_SELF_TEST', ...
        'Synthetic self-test failed: %s.', name);
end
end
