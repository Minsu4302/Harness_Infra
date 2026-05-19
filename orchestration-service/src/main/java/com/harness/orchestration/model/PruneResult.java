package com.harness.orchestration.model;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class PruneResult {

    private String prunedDiff;
    private int originalChars;
    private int prunedChars;
    private int filesRemoved;
    private boolean truncated;

    public int savedChars() {
        return originalChars - prunedChars;
    }

    public String summary() {
        return String.format("pruned %d→%d chars (-%d), %d files removed%s",
                originalChars, prunedChars, savedChars(),
                filesRemoved, truncated ? ", truncated" : "");
    }
}
