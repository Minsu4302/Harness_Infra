package com.harness.orchestration.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.harness.orchestration.gateway.AnthropicGateway;
import com.harness.orchestration.model.AgentRequest;
import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.GateResult;
import com.harness.orchestration.model.OrchestrationPlan;
import com.harness.orchestration.model.OrchestrationPlan.AgentTask;
import com.harness.orchestration.model.PruneResult;
import com.harness.orchestration.pruner.ContextPruner;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrchestratorService {

    static final int AGENT_TIMEOUT_SECONDS = 120;

    private final AnthropicGateway anthropicGateway;
    private final ModelRouter modelRouter;
    private final ReviewAgentService reviewAgentService;
    private final SecurityAgentService securityAgentService;
    private final TestGenAgentService testGenAgentService;
    private final DeploymentGateService deploymentGateService;
    private final ContextPruner contextPruner;
    private final ObjectMapper objectMapper;

    private static final String PLANNER_PROMPT = """
            You are an AI pipeline orchestrator. Analyze the git diff and decide which agents to run and which model to assign.

            Available agents:
            - "review"   : code quality, readability, patterns
            - "security" : vulnerabilities, secrets, injections
            - "test-gen" : generate unit tests for new/changed methods

            Available models:
            - "claude"  : best for nuanced reasoning, complex code review
            - "gemini"  : best for pattern matching, security scanning, fast tasks

            Rules:
            - docs-only changes (*.md, *.txt): run "review" only with "gemini"
            - config/lock files (*.json, *.yaml, *.lock): run "security" only with "gemini"
            - new methods or classes: run all three agents
            - security-sensitive changes (auth, crypto, sql): always include "security" with "gemini"
            - assign "claude" to "review" when logic complexity is high

            Respond ONLY in this JSON format (no markdown):
            {
              "reasoning": "one sentence explaining your decision",
              "tasks": [
                {"agent": "security", "model": "gemini", "reason": "..."},
                {"agent": "review",   "model": "claude", "reason": "..."}
              ]
            }
            """;

    public GateResult orchestrate(AgentRequest request) {
        PruneResult pruned = contextPruner.prune(request.getDiff());
        log.info("[Pruner] {}", pruned.summary());

        AgentRequest prunedRequest = new AgentRequest();
        prunedRequest.setDiff(pruned.getPrunedDiff());
        prunedRequest.setPrTitle(request.getPrTitle());
        prunedRequest.setPrDescription(request.getPrDescription());
        prunedRequest.setLanguage(request.getLanguage());

        OrchestrationPlan plan = plan(prunedRequest);
        log.info("[Orchestrator] plan: {}", plan.getReasoning());

        Map<String, AgentResult> results = executeAgentsInParallel(plan.getTasks(), prunedRequest);

        return deploymentGateService.evaluate(
                results.getOrDefault("review",   skipResult("review")),
                results.getOrDefault("security", skipResult("security")),
                results.getOrDefault("test-gen", skipResult("test-gen"))
        );
    }

    public OrchestrationPlan plan(AgentRequest request) {
        String response = anthropicGateway.complete(
                PLANNER_PROMPT, "Git Diff:\n```\n" + request.getDiff() + "\n```");
        return parsePlan(response);
    }

    private Map<String, AgentResult> executeAgentsInParallel(List<AgentTask> tasks, AgentRequest request) {
        Map<String, AgentResult> results = new ConcurrentHashMap<>();

        List<CompletableFuture<Void>> futures = tasks.stream()
                .map(task -> CompletableFuture
                        .supplyAsync(() -> {
                            var gateway = modelRouter.route(task.getModel());
                            log.info("[Orchestrator] running {} via {}", task.getAgent(), gateway.modelName());
                            return switch (task.getAgent()) {
                                case "review"   -> reviewAgentService.review(request, gateway);
                                case "security" -> securityAgentService.scan(request, gateway);
                                case "test-gen" -> testGenAgentService.generate(request, gateway);
                                default         -> skipResult(task.getAgent());
                            };
                        })
                        .orTimeout(AGENT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                        .exceptionally(ex -> {
                            log.warn("[Orchestrator] {} timed out or failed: {}", task.getAgent(), ex.getMessage());
                            return timeoutResult(task.getAgent());
                        })
                        .thenAccept(result -> results.put(task.getAgent(), result))
                )
                .collect(Collectors.toList());

        CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();
        return results;
    }

    private OrchestrationPlan parsePlan(String json) {
        try {
            String cleaned = json.trim();
            int start = cleaned.indexOf('{');
            int end   = cleaned.lastIndexOf('}');
            if (start >= 0 && end > start) {
                cleaned = cleaned.substring(start, end + 1);
            }
            return objectMapper.readValue(cleaned, OrchestrationPlan.class);
        } catch (Exception e) {
            log.warn("[Orchestrator] plan parse failed, falling back to full run: {}", e.getMessage());
            return defaultPlan();
        }
    }

    private OrchestrationPlan defaultPlan() {
        OrchestrationPlan plan = new OrchestrationPlan();
        plan.setReasoning("fallback: parse error, running all agents");
        plan.setTasks(List.of(
                task("security", "gemini"),
                task("review",   "claude"),
                task("test-gen", "gemini")
        ));
        return plan;
    }

    private AgentTask task(String agent, String model) {
        AgentTask t = new AgentTask();
        t.setAgent(agent);
        t.setModel(model);
        t.setReason("default");
        return t;
    }

    private AgentResult skipResult(String agentType) {
        return AgentResult.builder()
                .agentType(agentType).status(AgentResult.Status.PASS)
                .summary("skipped by orchestrator").issues(List.of()).build();
    }

    private AgentResult timeoutResult(String agentType) {
        return AgentResult.builder()
                .agentType(agentType).status(AgentResult.Status.WARN)
                .summary("agent timed out after " + AGENT_TIMEOUT_SECONDS + "s — skipped")
                .issues(List.of()).build();
    }
}
