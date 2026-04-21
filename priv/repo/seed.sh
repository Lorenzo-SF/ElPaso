#!/usr/bin/env bash
# Script para insertar datos de prueba
# Uso: ./priv/repo/seed.sh

psql -U postgres -d elpaso_dev -c "
-- Verificar si ya hay datos
SELECT 'routing_decisions existentes:' as info, COUNT(*) as count FROM routing_decisions;
" && exit 0

echo "Insertando 500 decisiones de prueba..."

# Generar datos usando generate_series
psql -U postgres -d elpaso_dev -c "
-- Insertar 500 decisiones aleatorias
WITH 
  models AS (
    SELECT unnest(ARRAY['claude-3-opus-20240229', 'claude-3-sonnet-20240229', 'claude-3-haiku-20240307', 'claude-3-5-sonnet-20241022', 'claude-3-5-haiku-20241022']) AS model
  ),
  tasks AS (
    SELECT unnest(ARRAY['code', 'reasoning', 'summarization', 'question_answer', 'creative', 'translation', 'unknown']) AS task
  ),
  outcomes AS (
    SELECT unnest(ARRAY['success', 'retry', 'error']) AS outcome
  ),
  languages AS (
    SELECT unnest(ARRAY['en', 'es', 'fr', 'de', 'zh', 'ja']) AS lang
  ),
  base AS (
    SELECT 
      generate_series(1, 500) AS i,
      random() AS r,
      (random() * 89)::int AS days_ago,
      (random() * 24)::int AS hours_ago
    FROM generate_series(1, 1)
  )
INSERT INTO routing_decisions (
  request_id, session_id, model_id, task_type, selected_model, runner_up,
  token_estimate, complexity_score, language, scores, reason, outcome,
  decision_latency_us, decided_at, inserted_at, updated_at
)
SELECT 
  'req_' || (base.i * 1000 + (random() * 1000)::int)::text AS request_id,
  'session_' || (1 + (random() * 50)::int)::text AS session_id,
  (SELECT model FROM models OFFSET (random() * 5)::int LIMIT 1) AS model_id,
  (SELECT task FROM tasks OFFSET (random() * 7)::int LIMIT 1) AS task_type,
  (SELECT model FROM models OFFSET (random() * 5)::int LIMIT 1) AS selected_model,
  (SELECT model FROM models OFFSET (random() * 5)::int LIMIT 1) AS runner_up,
  (1000 + (random() * 14000)::int) AS token_estimate,
  (0.1 + random() * 0.8)::numeric(3,2) AS complexity_score,
  (SELECT lang FROM languages OFFSET (random() * 6)::int LIMIT 1) AS language,
  '{}'::jsonb AS scores,
  'Best fit for ' || (SELECT task FROM tasks OFFSET (random() * 7)::int LIMIT 1) || ' task' AS reason,
  (SELECT outcome FROM outcomes OFFSET (random() * 3)::int LIMIT 1) AS outcome,
  (500 + (random() * 7000)::int) AS decision_latency_us,
  NOW() - (base.days_ago || ' days')::interval - (base.hours_ago || ' hours')::interval AS decided_at,
  NOW() - (base.days_ago || ' days')::interval - (base.hours_ago || ' hours')::interval AS inserted_at,
  NOW() - (base.days_ago || ' days')::interval - (base.hours_ago || ' hours')::interval AS updated_at
FROM base
CROSS JOIN models, tasks, outcomes, languages;
"

echo "Verificando..."

psql -U postgres -d elpaso_dev -c "
SELECT 'Total:' as info, COUNT(*) as count FROM routing_decisions
UNION ALL
SELECT 'Por modelo:', COUNT(*) FROM routing_decisions GROUP BY model_id ORDER BY 2 DESC LIMIT 5
UNION ALL
SELECT 'Por task:', COUNT(*) FROM routing_decisions GROUP BY task_type ORDER BY 2 DESC LIMIT 5
UNION ALL
SELECT 'Por outcome:', COUNT(*) FROM routing_decisions GROUP BY outcome ORDER BY 2 DESC LIMIT 3;
"

echo "=== Seed completado ==="
echo "Ejecuta: mix elpaso router tune"