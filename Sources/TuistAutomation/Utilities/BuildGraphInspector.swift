import Foundation
import TSCBasic
import TuistCore
import TuistGraph
import TuistSupport

public protocol BuildGraphInspecting {
    /// Returns the build arguments to be used with the given target.
    /// - Parameter project: Project whose build arguments will be returned.
    /// - Parameter target: Target whose build arguments will be returned.
    /// - Parameter configuration: The configuration to be built. When nil, it defaults to the configuration specified in the scheme.
    /// - Parameter skipSigning: Skip code signing during build that is not required to be signed (eg. build for testing on iOS Simulator)
    func buildArguments(project: Project, target: Target, configuration: String?, skipSigning: Bool) -> [XcodeBuildArgument]

    /// Given a directory, it returns the first .xcworkspace found.
    /// - Parameter path: Found .xcworkspace.
    func workspacePath(directory: AbsolutePath) throws -> AbsolutePath?

    ///  From the list of buildable targets of the given scheme, it returns the first one.
    /// - Parameters:
    ///   - scheme: Scheme in which to look up the target.
    ///   - graph: Dependency graph.
    func buildableTarget(scheme: Scheme, graph: Graph) -> (Project, Target)?

    ///  From the list of testable targets of the given scheme, it returns the first one.
    /// - Parameters:
    ///   - scheme: Scheme in which to look up the target.
    ///   - graph: Dependency graph.
    func testableTarget(scheme: Scheme, graph: Graph) -> (Project, Target)?

    /// Given a graph, it returns a list of buildable schemes.
    /// - Parameter graph: Dependency graph.
    func buildableSchemes(graph: Graph) -> [Scheme]

    /// Given a graph, it returns a list of buildable schemes that are part of the entry node
    /// - Parameters:
    ///     - graph: Dependency graph
    func buildableEntrySchemes(graph: Graph) -> [Scheme]

    /// Given a graph, it returns a list of test schemes (those that include only one test target).
    /// - Parameter graph: Dependency graph.
    func testSchemes(graph: Graph) -> [Scheme]

    /// Given a graph, it returns a list of testable schemes.
    /// - Parameter graph: Dependency graph.
    func testableSchemes(graph: Graph) -> [Scheme]

    /// Schemes generated by `AutogeneratedProjectSchemeWorkspaceMapper`
    /// - Parameters:
    ///     - graph: Dependency graph
    func projectSchemes(graph: Graph) -> [Scheme]
}

public class BuildGraphInspector: BuildGraphInspecting {
    public init() {}

    public func buildArguments(project: Project, target: Target, configuration: String?, skipSigning: Bool) -> [XcodeBuildArgument] {
        var arguments: [XcodeBuildArgument]
        if target.platform == .macOS {
            arguments = [.sdk(target.platform.xcodeDeviceSDK)]
        } else {
            arguments = [.sdk(target.platform.xcodeSimulatorSDK!)]
        }

        // Configuration
        if let configuration = configuration {
            if (target.settings ?? project.settings)?.configurations.first(where: { $0.key.name == configuration }) != nil {
                arguments.append(.configuration(configuration))
            } else {
                logger.warning("The scheme's targets don't have the given configuration \(configuration). Defaulting to the scheme's default.")
            }
        }

        // Signing
        if skipSigning {
            arguments += [
                .xcarg("CODE_SIGN_IDENTITY", ""),
                .xcarg("CODE_SIGNING_REQUIRED", "NO"),
                .xcarg("CODE_SIGN_ENTITLEMENTS", ""),
                .xcarg("CODE_SIGNING_ALLOWED", "NO"),
            ]
        }

        return arguments
    }

    public func buildableTarget(scheme: Scheme, graph: Graph) -> (Project, Target)? {
        guard
            scheme.buildAction?.targets.isEmpty == false,
            let buildTarget = scheme.buildAction?.targets.first
        else {
            return nil
        }

        return graph.target(path: buildTarget.projectPath, name: buildTarget.name).map { ($0.project, $0.target) }
    }

    public func testableTarget(scheme: Scheme, graph: Graph) -> (Project, Target)? {
        if scheme.testAction?.targets.count == 0 {
            return nil
        }
        let testTarget = scheme.testAction!.targets.first!
        return graph.target(path: testTarget.target.projectPath, name: testTarget.target.name).map { ($0.project, $0.target) }
    }

    public func buildableSchemes(graph: Graph) -> [Scheme] {
        graph.schemes
            .filter { $0.buildAction?.targets.isEmpty == false }
            .sorted(by: { $0.name < $1.name })
    }

    public func buildableEntrySchemes(graph: Graph) -> [Scheme] {
        let projects = Set(graph.entryNodes.compactMap { ($0 as? TargetNode)?.project })
        return projects
            .flatMap(\.schemes)
            .filter { $0.buildAction?.targets.isEmpty == false }
            .sorted(by: { $0.name < $1.name })
    }

    public func testableSchemes(graph: Graph) -> [Scheme] {
        graph.schemes
            .filter { $0.testAction?.targets.isEmpty == false }
            .sorted(by: { $0.name < $1.name })
    }

    public func testSchemes(graph: Graph) -> [Scheme] {
        graph.targets.values.flatMap { target -> [Scheme] in
            target
                .filter { $0.target.product == .unitTests || $0.target.product == .uiTests }
                .flatMap { target -> [Scheme] in
                    target.project.schemes
                        .filter { $0.targetDependencies().map(\.name) == [target.name] }
                }
        }
        .filter { $0.testAction?.targets.isEmpty == false }
        .sorted(by: { $0.name < $1.name })
    }

    public func projectSchemes(graph: Graph) -> [Scheme] {
        graph.workspace.schemes
            .filter { $0.name.contains("\(graph.workspace.name)-Project") }
            .sorted(by: { $0.name < $1.name })
    }

    public func workspacePath(directory: AbsolutePath) throws -> AbsolutePath? {
        try directory.glob("**/*.xcworkspace")
            .filter {
                try FileHandler.shared.contentsOfDirectory($0)
                    .map(\.basename)
                    .contains(Constants.tuistGeneratedFileName)
            }
            .first
    }
}
