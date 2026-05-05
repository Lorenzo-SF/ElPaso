defmodule ElPaso.Repo.Migrations.PersonalityDrivenRouting do
  use Ecto.Migration

  def up do
    # ═══════════════════════════════════════════════════════════════════════
    # 1. Añadir columnas de routing a personalities
    # ═══════════════════════════════════════════════════════════════════════
    alter table(:personalities) do
      add :model_id, references(:models, type: :uuid, on_delete: :nilify_all)
      add :engine_id, references(:engines, type: :uuid, on_delete: :nilify_all)
      add :config, :map, default: %{}
      add :trigger_keywords, {:array, :string}, default: []
      add :trigger_task_types, {:array, :string}, default: []
      add :detection_rules, :map, default: %{}
      add :priority, :integer, default: 0
      add :is_default, :boolean, default: false
    end

    create index(:personalities, [:is_default])
    create index(:personalities, [:priority])

    # ═══════════════════════════════════════════════════════════════════════
    # 2. Migrar datos de profiles → personalities (si existen)
    # ═══════════════════════════════════════════════════════════════════════
    execute """
    UPDATE personalities p
    SET model_id  = pr.model_id,
        engine_id = pr.engine_id,
        config    = COALESCE(pr.config, '{}')
    FROM profiles pr
    WHERE p.id = pr.personality_id;
    """

    # ═══════════════════════════════════════════════════════════════════════
    # 3. Eliminar tabla profiles (redundante)
    # ═══════════════════════════════════════════════════════════════════════
    drop table(:profiles)

    # ═══════════════════════════════════════════════════════════════════════
    # 4. Restricción: solo una personalidad por defecto
    # ═══════════════════════════════════════════════════════════════════════
    execute """
    CREATE UNIQUE INDEX one_default_personality
    ON personalities (is_default)
    WHERE is_default = true;
    """

    # ═══════════════════════════════════════════════════════════════════════
    # 5. Insertar las 5 personalidades preconfiguradas
    # ═══════════════════════════════════════════════════════════════════════

    execute """
    INSERT INTO personalities (id, name, description, system_prompt, active,
                               model_id, engine_id, config,
                               trigger_keywords, trigger_task_types,
                               detection_rules, priority, is_default,
                               created_at, updated_at)
    SELECT
      gen_random_uuid(), 'coder',
      'Desarrollo de software: código, refactors, PRs, debugging, tests.',
      'Eres un ingeniero de software senior experto. Escribes código limpio, idiomático y bien documentado. Explicas tus decisiones técnicas. Usas patrones de diseño. Prefieres soluciones simples y mantenibles. Cuando refactorizas, mantienes todas las validaciones originales.',
      true,
      m.id, e.id,
      '{"temperature": 0.2, "top_p": 0.9, "max_tokens": 4800}'::jsonb,
      ARRAY['refactoriza', 'implementa', 'test', 'PR', 'bug', 'fix', 'debug', 'compila', 'migra', 'migration', 'endpoint', 'api', 'módulo', 'función', 'typespec', 'pattern match', 'gen_server', 'supervisor', 'ecto', 'schema'],
      ARRAY['code', 'debug', 'refactor', 'testing'],
      '{"complexity_min": 0.3, "complexity_max": 0.9, "language_hint": ["elixir", "rust", "python", "typescript", "bash"], "regex_hints": ["\\\\b(def|fn|function|class|module)\\\\b"]}'::jsonb,
      10, false, now(), now()
    FROM models m, engines e
    WHERE m.name = 'coder-fim' AND e.name = 'llama-local'
    ON CONFLICT (name) DO NOTHING;
    """

    execute """
    INSERT INTO personalities (id, name, description, system_prompt, active,
                               model_id, engine_id, config,
                               trigger_keywords, trigger_task_types,
                               detection_rules, priority, is_default,
                               created_at, updated_at)
    SELECT
      gen_random_uuid(), 'architect',
      'Arquitectura de software: diseño de sistemas, trade-offs, planificación a largo plazo.',
      'Eres un arquitecto de software con 20 años de experiencia. Analizas requisitos, diseñas sistemas escalables, evalúas trade-offs entre rendimiento, mantenibilidad y coste. Piensas en el largo plazo. Documentas tus decisiones de arquitectura con ADRs. Conoces patrones: microservicios, event-driven, CQRS, hexagonal, etc.',
      true,
      m.id, e.id,
      '{"temperature": 0.4, "top_p": 0.9, "max_tokens": 8192}'::jsonb,
      ARRAY['arquitectura', 'diseña', 'escalable', 'sistema', 'ADR', 'trade-off', 'tradeoff', 'event-driven', 'microservicio', 'monolito', 'hexagonal', 'cqrs', 'pipeline', 'infraestructura', 'cluster', 'distribuido', 'particionado'],
      ARRAY['architecture', 'reasoning', 'planning', 'code'],
      '{"complexity_min": 0.6, "complexity_max": 1.0, "language_hint": ["elixir", "erlang", "rust"], "regex_hints": ["\\\\b(arquitectura|architecture|design|diseño)\\\\b"]}'::jsonb,
      20, false, now(), now()
    FROM models m, engines e
    WHERE m.name = 'thinker-opus' AND e.name = 'llama-local'
    ON CONFLICT (name) DO NOTHING;
    """

    execute """
    INSERT INTO personalities (id, name, description, system_prompt, active,
                               model_id, engine_id, config,
                               trigger_keywords, trigger_task_types,
                               detection_rules, priority, is_default,
                               created_at, updated_at)
    SELECT
      gen_random_uuid(), 'legal-es',
      'Asistente jurídico español. Basado en legislación. NO inventa información legal.',
      'Eres un asistente jurídico especializado en legislación española. Respondes BASÁNDOTE EXCLUSIVAMENTE en los documentos y legislación proporcionados. Citas artículos y disposiciones concretas indicando la fuente. Si no encuentras la información, dices: "No consta en los documentos analizados". NO inventas legislación.',
      true,
      m.id, e.id,
      '{"temperature": 0.15, "top_p": 0.9, "max_tokens": 4096}'::jsonb,
      ARRAY['ley', 'BOE', 'pensión', 'jubilación', 'IRPF', 'seguridad social', 'excedencia', 'contrato', 'legal', 'jurídico', 'artículo', 'disposición', 'normativa', 'real decreto', 'estatuto', 'trabajadores', 'constitución', 'sentencia', 'tribunal'],
      ARRAY['legal', 'question_answer', 'summarization'],
      '{"complexity_min": 0.2, "complexity_max": 0.8}'::jsonb,
      30, false, now(), now()
    FROM models m, engines e
    WHERE m.name = 'thinker' AND e.name = 'llama-local'
    ON CONFLICT (name) DO NOTHING;
    """

    execute """
    INSERT INTO personalities (id, name, description, system_prompt, active,
                               model_id, engine_id, config,
                               trigger_keywords, trigger_task_types,
                               detection_rules, priority, is_default,
                               created_at, updated_at)
    SELECT
      gen_random_uuid(), 'tutor',
      'Tutor paciente y didáctico. Explica conceptos paso a paso desde lo básico.',
      'Eres un tutor paciente y didáctico. Explicas conceptos desde lo más básico, paso a paso, asegurándote de que el alumno entiende cada paso antes de avanzar. Usas analogías, ejemplos concretos y diagramas conceptuales cuando ayudan. Adaptas tu ritmo al nivel del alumno. Nunca asumes conocimiento previo.',
      true,
      m.id, e.id,
      '{"temperature": 0.5, "top_p": 0.9, "max_tokens": 4096}'::jsonb,
      ARRAY['explica', 'explicar', 'explicación', 'por qué', 'cómo funciona', 'qué es', 'define', 'definición', 'significa', 'diferencia entre', 'comparar', 'tutorial', 'paso a paso', 'aprender', 'guía'],
      ARRAY['question_answer', 'explanation'],
      '{"complexity_min": 0.0, "complexity_max": 0.5}'::jsonb,
      5, false, now(), now()
    FROM models m, engines e
    WHERE m.name = 'thinker' AND e.name = 'llama-local'
    ON CONFLICT (name) DO NOTHING;
    """

    execute """
    INSERT INTO personalities (id, name, description, system_prompt, active,
                               model_id, engine_id, config,
                               trigger_keywords, trigger_task_types,
                               detection_rules, priority, is_default,
                               created_at, updated_at)
    SELECT
      gen_random_uuid(), 'general',
      'Asistente general conversacional. Fallback cuando ninguna otra personalidad coincide.',
      'Eres un asistente útil, conversacional y directo. Respondes preguntas de todo tipo con precisión y sin rodeos. Si no sabes algo, lo dices claramente. Eres amable pero no empalagoso. Adaptas tu tono al contexto de la conversación.',
      true,
      m.id, e.id,
      '{"temperature": 0.7, "top_p": 0.9, "max_tokens": 4096}'::jsonb,
      ARRAY[]::text[],
      ARRAY[]::text[],
      '{}'::jsonb,
      1, true, now(), now()
    FROM models m, engines e
    WHERE m.name = 'gemma' AND e.name = 'llama-local'
    ON CONFLICT (name) DO NOTHING;
    """
  end

  def down do
    # Recrear profiles
    create table(:profiles, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :model_id, references(:models, type: :uuid)
      add :engine_id, references(:engines, type: :uuid)
      add :personality_id, references(:personalities, type: :uuid)
      add :config, :map, default: %{}
      add :active, :boolean, default: true
      add :description, :string
      timestamps()
    end
    create unique_index(:profiles, [:name])

    # Migrar datos de vuelta
    execute """
    INSERT INTO profiles (id, name, model_id, engine_id, personality_id, config, active, created_at, updated_at)
    SELECT gen_random_uuid(), p.name || '-default', p.model_id, p.engine_id, p.id, p.config, p.active, now(), now()
    FROM personalities p
    WHERE p.model_id IS NOT NULL;
    """

    # Eliminar columnas añadidas
    drop index(:personalities, [:is_default])
    drop index(:personalities, [:priority])
    execute "DROP INDEX IF EXISTS one_default_personality;"

    alter table(:personalities) do
      remove :is_default
      remove :priority
      remove :detection_rules
      remove :trigger_task_types
      remove :trigger_keywords
      remove :config
      remove :engine_id
      remove :model_id
    end
  end
end
