import Foundation

/// Walks from a working directory toward `/`.
///
/// The git root is the nearest directory that contains a `.git` file or directory
/// (a worktree's `.git` file counts). Manifests are considered only between the
/// working directory and that git root, so a `package.json` outside the repo
/// cannot claim the process. The nearest manifest wins. With no manifest, the
/// project name is the git root's directory name, then the working directory's.
public struct ProjectDetector: Sendable {
    private let probe: any FileSystemProbe

    public init(probe: any FileSystemProbe) {
        self.probe = probe
    }

    public func detect(workingDirectory: String) -> ProjectContext {
        let cwd = PathNormalizer.normalize(workingDirectory)
        let chain = PathNormalizer.ancestors(of: cwd)

        var gitRoot: String?
        for directory in chain where probe.entryExists(at: PathNormalizer.joining(directory, ".git")) {
            gitRoot = directory
            break
        }

        var manifestKind: ManifestKind?
        var manifestPath: String?
        var manifestDirectory: String?
        for directory in chain {
            for kind in ManifestKind.allCases {
                let path = PathNormalizer.joining(directory, kind.fileName)
                if probe.entryExists(at: path) {
                    manifestKind = kind
                    manifestPath = path
                    manifestDirectory = directory
                    break
                }
            }
            if manifestPath != nil { break }
            if let gitRoot, directory == gitRoot { break }
        }

        var projectName: String?
        if let manifestKind, let manifestPath, let manifestDirectory {
            let contents = probe.read(at: manifestPath) ?? ""
            projectName = ManifestNameParser.name(
                kind: manifestKind,
                contents: contents,
                directory: manifestDirectory
            )
        }
        if projectName == nil {
            if let gitRoot, gitRoot != "/" {
                projectName = PathNormalizer.basename(gitRoot)
            } else if cwd != "/" {
                projectName = PathNormalizer.basename(cwd)
            }
        }

        return ProjectContext(
            workingDirectory: cwd,
            gitRoot: gitRoot,
            projectName: projectName,
            manifestKind: manifestKind,
            manifestPath: manifestPath
        )
    }
}
