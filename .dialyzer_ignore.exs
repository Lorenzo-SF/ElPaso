[
  # PersonalityManager usa tipos de Ecto que Dialyzer no carga
  {"lib/el_paso/domain/personality_manager.ex", :unknown_type},

  # ProfileManager usa tipos de módulos que no existen
  {"lib/el_paso/domain/profile_manager.ex", :unknown_type},

  # Engine usa tipos de módulos que no existen
  {"lib/el_paso/engine.ex", :unknown_type}
]
