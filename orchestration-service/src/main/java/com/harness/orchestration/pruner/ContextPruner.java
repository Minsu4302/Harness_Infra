package com.harness.orchestration.pruner;

import com.harness.orchestration.model.PruneResult;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

@Component
public class ContextPruner {

    private static final int MAX_CHARS = 8000;

    private static final Set<String> EXCLUDED_EXTENSIONS = Set.of(
            ".lock", ".png", ".jpg", ".jpeg", ".gif", ".ico", ".svg",
            ".woff", ".woff2", ".ttf", ".eot", ".map", ".bin", ".zip",
            ".jar", ".class", ".pdf", ".mp4", ".mp3"
    );

    private static final Set<String> EXCLUDED_FILENAMES = Set.of(
            "package-lock.json", "yarn.lock", "Gemfile.lock",
            "poetry.lock", "pnpm-lock.yaml", "composer.lock",
            "gradle-wrapper.jar", ".DS_Store"
    );

    private static final Set<String> EXCLUDED_PATH_PATTERNS = Set.of(
            "node_modules/", ".gradle/", "build/", "dist/", ".idea/", ".vscode/"
    );

    public PruneResult prune(String diff) {
        if (diff == null || diff.isBlank()) {
            return PruneResult.builder()
                    .prunedDiff("").originalChars(0).prunedChars(0)
                    .filesRemoved(0).truncated(false).build();
        }

        int originalChars = diff.length();
        List<String> sections = splitByFile(diff);
        List<String> kept = new ArrayList<>();
        int filesRemoved = 0;

        for (String section : sections) {
            String filename = extractFilename(section);
            if (shouldExclude(filename)) {
                filesRemoved++;
            } else {
                kept.add(section);
            }
        }

        String joined = String.join("\n", kept).stripTrailing();
        boolean truncated = false;

        if (joined.length() > MAX_CHARS) {
            joined = joined.substring(0, MAX_CHARS) + "\n... [diff truncated by ContextPruner]";
            truncated = true;
        }

        return PruneResult.builder()
                .prunedDiff(joined)
                .originalChars(originalChars)
                .prunedChars(joined.length())
                .filesRemoved(filesRemoved)
                .truncated(truncated)
                .build();
    }

    private List<String> splitByFile(String diff) {
        List<String> sections = new ArrayList<>();
        String[] lines = diff.split("\n");
        StringBuilder current = new StringBuilder();

        for (String line : lines) {
            if (line.startsWith("diff --git") && !current.isEmpty()) {
                sections.add(current.toString());
                current = new StringBuilder();
            }
            current.append(line).append("\n");
        }
        if (!current.isEmpty()) {
            sections.add(current.toString());
        }
        return sections;
    }

    private String extractFilename(String section) {
        for (String line : section.split("\n")) {
            if (line.startsWith("diff --git")) {
                String[] parts = line.split(" ");
                if (parts.length >= 3) {
                    return parts[parts.length - 1].replaceFirst("^b/", "");
                }
            }
        }
        return "";
    }

    private boolean shouldExclude(String filename) {
        if (filename.isBlank()) return false;

        String lower = filename.toLowerCase();

        if (EXCLUDED_FILENAMES.contains(extractBasename(lower))) return true;

        for (String ext : EXCLUDED_EXTENSIONS) {
            if (lower.endsWith(ext)) return true;
        }

        for (String pattern : EXCLUDED_PATH_PATTERNS) {
            if (lower.contains(pattern)) return true;
        }

        return false;
    }

    private String extractBasename(String path) {
        int slash = path.lastIndexOf('/');
        return slash >= 0 ? path.substring(slash + 1) : path;
    }
}
