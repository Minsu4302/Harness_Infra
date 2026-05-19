package com.harness.orchestration.model;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class AgentResult {

    public enum Status { PASS, WARN, FAIL }

    private String agentType;
    private Status status;
    private String summary;
    private List<String> issues;
    private String generatedCode;
}
