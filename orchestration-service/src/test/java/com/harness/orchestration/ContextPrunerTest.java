package com.harness.orchestration;

import com.harness.orchestration.model.PruneResult;
import com.harness.orchestration.pruner.ContextPruner;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ContextPrunerTest {

    private ContextPruner pruner;

    @BeforeEach
    void setUp() {
        pruner = new ContextPruner();
    }

    @Test
    void prune_removesLockFile() {
        String diff = """
                diff --git a/src/Main.java b/src/Main.java
                +public class Main {}
                diff --git a/package-lock.json b/package-lock.json
                +  "lockfileVersion": 3,
                +  "requires": true
                """;

        PruneResult result = pruner.prune(diff);

        assertThat(result.getPrunedDiff()).contains("Main.java");
        assertThat(result.getPrunedDiff()).doesNotContain("package-lock.json");
        assertThat(result.getFilesRemoved()).isEqualTo(1);
    }

    @Test
    void prune_removesBinaryExtension() {
        String diff = """
                diff --git a/src/Service.java b/src/Service.java
                +public class Service {}
                diff --git a/assets/logo.png b/assets/logo.png
                Binary files differ
                """;

        PruneResult result = pruner.prune(diff);

        assertThat(result.getPrunedDiff()).contains("Service.java");
        assertThat(result.getPrunedDiff()).doesNotContain("logo.png");
        assertThat(result.getFilesRemoved()).isEqualTo(1);
    }

    @Test
    void prune_truncatesOversizedDiff() {
        String largeDiff = "diff --git a/Big.java b/Big.java\n" + "+x".repeat(5000);

        PruneResult result = pruner.prune(largeDiff);

        assertThat(result.isTruncated()).isTrue();
        assertThat(result.getPrunedChars()).isLessThanOrEqualTo(8100);
        assertThat(result.getPrunedDiff()).endsWith("[diff truncated by ContextPruner]");
    }

    @Test
    void prune_passesCleanDiffUnchanged() {
        String diff = "diff --git a/Foo.java b/Foo.java\n+public class Foo {}";

        PruneResult result = pruner.prune(diff);

        assertThat(result.getFilesRemoved()).isEqualTo(0);
        assertThat(result.isTruncated()).isFalse();
        assertThat(result.getPrunedDiff()).contains("Foo.java");
    }

    @Test
    void prune_handlesEmptyDiff() {
        PruneResult result = pruner.prune("");

        assertThat(result.getPrunedDiff()).isEmpty();
        assertThat(result.getOriginalChars()).isEqualTo(0);
    }

    @Test
    void prune_removesMultipleExcludedFiles() {
        String diff = """
                diff --git a/app.js b/app.js
                +const x = 1;
                diff --git a/yarn.lock b/yarn.lock
                +lockfile v1
                diff --git a/icon.png b/icon.png
                Binary
                diff --git a/styles.css.map b/styles.css.map
                +{}
                """;

        PruneResult result = pruner.prune(diff);

        assertThat(result.getFilesRemoved()).isEqualTo(3);
        assertThat(result.getPrunedDiff()).contains("app.js");
    }

    @Test
    void pruneResult_summaryContainsStats() {
        String diff = "diff --git a/package-lock.json b/package-lock.json\n+lock content";
        PruneResult result = pruner.prune(diff);

        assertThat(result.summary()).contains("files removed");
    }
}
