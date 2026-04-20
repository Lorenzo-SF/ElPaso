## Tabla resumen del roadmap

| Versión | Objetivo                       | Módulos nuevos principales                                            |
| ------- | ------------------------------ | --------------------------------------------------------------------- |
| V0      | Definición del proyecto        | —                                                                     |
| V1.0    | Sistema funcional local        | Config, ModelManager, Context.\*, Router, HTTP, Security básica       |
| V1.1    | Contexto semántico + madurez   | EmbeddingClient, SemanticRetriever, Tokenizer, Config.Migrator        |
| V1.2    | Diagnóstico y ajuste           | RouterStats, RouterTuner, CLI.Bench, Config.Diff                      |
| V1.3    | Observabilidad + multi-usuario | HTTP.Dashboard, Telemetry.Store, Security.Auth, HTTP.WebSocketHandler |
| V2.0    | Integraciones + extensibilidad | HTTP.AnthropicProxy, Plugin.Loader, ModelDownloader                   |
| V2.1    | Clustering multi-nodo          | Cluster.NodeRegistry, Router.Cluster, libcluster                      |
| V2.2    | Aprendizaje adaptativo         | RouterAnalyzer, AutoTuner                                             |
| V3.0    | ElPaso como servicio           | CostManager, Security.JWT, Storage.S3Adapter, HTTP.Admin              |

**Caminos de dependencia obligatorios**:

- V3.0 requiere V2.1 (clustering necesario para modo servicio real)
- V2.2 requiere V1.2 (RouterTuner base + datos acumulados)
- V2.1 requiere V1.3 (multi-usuario prerequisito de multi-nodo)
- Cada versión requiere la inmediatamente anterior; las no-críticas se pueden saltar
  (por ejemplo, V2.0 antes de V2.2 si el aprendizaje no es prioritario)
