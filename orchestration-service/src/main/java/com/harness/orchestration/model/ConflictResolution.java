package com.harness.orchestration.model;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ConflictResolution {

    private GateResult.Decision decision;
    private String reason;
    private boolean wasConflict;
}
