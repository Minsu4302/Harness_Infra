package com.harness.orchestration.model;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class GateResult {

    public enum Decision { APPROVED, REJECTED }

    private Decision decision;
    private String reason;
    private String markdownReport;
}
