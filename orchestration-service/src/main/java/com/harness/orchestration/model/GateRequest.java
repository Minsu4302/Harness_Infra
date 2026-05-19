package com.harness.orchestration.model;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class GateRequest {

    @NotNull
    private AgentResult reviewResult;

    @NotNull
    private AgentResult securityResult;

    @NotNull
    private AgentResult testGenResult;
}
