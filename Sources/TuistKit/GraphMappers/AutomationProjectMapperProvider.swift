import Foundation
import TSCBasic
import TuistAutomation
import TuistCore
import TuistGenerator
import TuistGraph
import TuistSupport

/// Custom mapper provider for automation features
/// It uses default `ProjectMapperProvider` but adds its own on top
final class AutomationProjectMapperProvider: ProjectMapperProviding {
    private let projectMapperProvider: ProjectMapperProviding

    init(
        projectMapperProvider: ProjectMapperProviding = ProjectMapperProvider()
    ) {
        self.projectMapperProvider = projectMapperProvider
    }

    func mapper(config: Config) -> ProjectMapping {
        var mappers: [ProjectMapping] = []
        mappers.append(projectMapperProvider.mapper(config: config))

        if config.generationOptions.contains(.disableAutogeneratedSchemes) {
            mappers.append(
                AutogeneratedSchemesProjectMapper(
                    enableCodeCoverage: config.generationOptions.contains(.enableCodeCoverage)
                )
            )
        }

        return SequentialProjectMapper(mappers: mappers)
    }
}
