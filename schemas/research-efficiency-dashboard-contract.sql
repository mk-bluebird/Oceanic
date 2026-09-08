CREATE VIEW v_research_efficiency_dashboard AS
SELECT
    topic,
    research_efficiency_score,
    CASE
        WHEN research_efficiency_score IS NULL THEN 'not_computable'
        WHEN research_efficiency_score >= 0.80 THEN 'high'
        WHEN research_efficiency_score >= 0.50 THEN 'moderate'
        ELSE 'low'
    END AS efficiency_status,
    CASE
        WHEN research_efficiency_score IS NULL THEN 1
        ELSE 0
    END AS missing_efficiency_measurement
FROM v_research_efficiency_by_topic;
