package com.harness.orchestration.model;

import lombok.Data;

import java.util.List;

@Data
public class OrchestrationPlan {

    private List<AgentTask> tasks;
    private String reasoning;

    @Data
    public static class AgentTask {
        private String agent;   // "review" | "security" | "test-gen"
        private String model;   // "claude" | "gemini"
        private String reason;
    }
}
