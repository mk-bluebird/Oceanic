package eco_restoration.lineage;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;
import java.util.Objects;

public final class HexLineageIdentity {
    private HexLineageIdentity() {
    }

    public record LineageInput(
        String schemaVersion,
        String dataClass,
        String hexAnchor,
        String spatialSchemeVersion,
        String observedAtUtc,
        String validFromUtc,
        String validToUtc,
        String modelVersion,
        String parameterVersion,
        String canonicalPayload,
        List<String> parentContentIds
    ) {
        public LineageInput {
            requireText("schemaVersion", schemaVersion);
            requireText("dataClass", dataClass);
            requireText("hexAnchor", hexAnchor);
            requireText("spatialSchemeVersion", spatialSchemeVersion);
            requireText("observedAtUtc", observedAtUtc);
            requireText("modelVersion", modelVersion);
            requireText("parameterVersion", parameterVersion);
            requireText("canonicalPayload", canonicalPayload);
            parentContentIds = List.copyOf(Objects.requireNonNull(
                parentContentIds,
                "parentContentIds must not be null"
            ));
            parentContentIds.forEach(parent -> requireText("parentContentId", parent));
        }
    }

    public static String contentId(LineageInput input) {
        Objects.requireNonNull(input, "input must not be null");

        String canonicalFrame = canonicalFrame(input);

        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(canonicalFrame.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException error) {
            throw new IllegalStateException("SHA-256 is unavailable in this Java runtime.", error);
        }
    }

    public static String canonicalFrame(LineageInput input) {
        List<String> parents = new ArrayList<>(input.parentContentIds());
        parents.sort(Comparator.naturalOrder());

        return String.join(
            "\n",
            "schema_version=" + escape(input.schemaVersion()),
            "data_class=" + escape(input.dataClass()),
            "hex_anchor=" + escape(input.hexAnchor()),
            "spatial_scheme_version=" + escape(input.spatialSchemeVersion()),
            "observed_at_utc=" + escape(input.observedAtUtc()),
            "valid_from_utc=" + escape(nullable(input.validFromUtc())),
            "valid_to_utc=" + escape(nullable(input.validToUtc())),
            "model_version=" + escape(input.modelVersion()),
            "parameter_version=" + escape(input.parameterVersion()),
            "parent_count=" + parents.size(),
            "parents=" + escape(String.join(",", parents)),
            "payload=" + escape(input.canonicalPayload())
        );
    }

    private static String nullable(String value) {
        return value == null ? "" : value;
    }

    private static String escape(String value) {
        return value
            .replace("\\", "\\\\")
            .replace("\n", "\\n")
            .replace("=", "\\=");
    }

    private static void requireText(String field, String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must not be blank.");
        }
    }
}
