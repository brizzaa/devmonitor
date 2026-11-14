import XCTest
@testable import DevMonitorCore

final class ManifestNameParserTests: XCTestCase {
    func testPackageJSONName() {
        XCTAssertEqual(ManifestNameParser.jsonName(#"{"name":"@acme/api","version":"1.0.0"}"#), "@acme/api")
        XCTAssertNil(ManifestNameParser.jsonName("{not json"))
    }

    func testCargoNameIgnoresOtherSections() {
        let toml = """
        [package]
        name = "devmonitor"
        version = "0.1.0"

        [lib]
        name = "not_this"

        [dependencies]
        serde = "1"
        """
        XCTAssertEqual(ManifestNameParser.cargoName(toml), "devmonitor")
        XCTAssertEqual(ManifestNameParser.cargoName("[package]\nname = 'quoted'\n"), "quoted")
    }

    func testGoModuleNameDropsVersionSuffix() {
        XCTAssertEqual(
            ManifestNameParser.goModuleName("module github.com/luca/devmonitor\n\ngo 1.22\n"),
            "devmonitor"
        )
        XCTAssertEqual(
            ManifestNameParser.goModuleName("module github.com/acme/foo/v2\n"),
            "foo"
        )
        XCTAssertEqual(ManifestNameParser.goModuleName("module example.com/v2\n"), "example.com")
    }

    func testPyprojectPrefersProjectOverPoetry() {
        let both = """
        [project]
        name = "svc"

        [tool.poetry]
        name = "other"
        """
        XCTAssertEqual(ManifestNameParser.pyprojectName(both), "svc")
        XCTAssertEqual(ManifestNameParser.pyprojectName("[tool.poetry]\nname = \"poem\"\n"), "poem")
    }

    func testSwiftPackagePomAndMix() {
        XCTAssertEqual(
            ManifestNameParser.swiftPackageName("let package = Package(\n    name: \"DevMonitor\",\n)"),
            "DevMonitor"
        )
        let pom = """
        <project>
          <parent><artifactId>parent-art</artifactId></parent>
          <artifactId>my-service</artifactId>
        </project>
        """
        XCTAssertEqual(ManifestNameParser.pomArtifactId(pom), "my-service")
        XCTAssertEqual(ManifestNameParser.mixAppName("app: :my_app,"), "my_app")
        XCTAssertEqual(ManifestNameParser.jsonName(#"{"name": "vendor/pkg"}"#), "vendor/pkg")
    }
}

final class ProjectDetectorTests: XCTestCase {
    func testNearestManifestInsideTheGitRootWins() {
        var fs = InMemoryFileSystem()
        fs.entries.insert("/repo/.git")
        fs.files["/repo/package.json"] = #"{"name":"monorepo"}"#
        fs.files["/repo/services/api/package.json"] = #"{"name":"api"}"#
        let project = ProjectDetector(probe: fs).detect(workingDirectory: "/repo/services/api")
        XCTAssertEqual(project.gitRoot, "/repo")
        XCTAssertEqual(project.projectName, "api")
        XCTAssertEqual(project.manifestKind, .packageJSON)
        XCTAssertEqual(project.manifestPath, "/repo/services/api/package.json")
        XCTAssertEqual(project.workingDirectory, "/repo/services/api")
    }

    func testDoesNotClaimAManifestOutsideTheGitRoot() {
        var fs = InMemoryFileSystem()
        fs.files["/outer/package.json"] = #"{"name":"outer"}"#
        fs.entries.insert("/outer/repo/.git")
        let project = ProjectDetector(probe: fs).detect(workingDirectory: "/outer/repo/app")
        XCTAssertEqual(project.gitRoot, "/outer/repo")
        XCTAssertNil(project.manifestKind)
        XCTAssertEqual(project.projectName, "repo")
    }

    func testGitFileMarksAWorktreeRoot() {
        var fs = InMemoryFileSystem()
        fs.files["/wt/.git"] = "gitdir: /repo/.git/worktrees/wt\n"
        fs.files["/wt/go.mod"] = "module github.com/luca/worker\n\ngo 1.22\n"
        let project = ProjectDetector(probe: fs).detect(workingDirectory: "/wt/cmd")
        XCTAssertEqual(project.gitRoot, "/wt")
        XCTAssertEqual(project.projectName, "worker")
        XCTAssertEqual(project.manifestKind, .goMod)
    }

    func testCargoTomlAndDirectoryFallbackWithoutGit() {
        var fs = InMemoryFileSystem()
        fs.files["/work/Cargo.toml"] = "[package]\nname = \"cli\"\n"
        let cargo = ProjectDetector(probe: fs).detect(workingDirectory: "/work/src")
        XCTAssertNil(cargo.gitRoot)
        XCTAssertEqual(cargo.projectName, "cli")
        XCTAssertEqual(cargo.manifestKind, .cargoToml)

        let plain = ProjectDetector(probe: InMemoryFileSystem()).detect(workingDirectory: "/tmp/scratch")
        XCTAssertEqual(plain.projectName, "scratch")
        XCTAssertNil(plain.manifestKind)
    }

    func testGemfileUsesTheDirectoryName() {
        var fs = InMemoryFileSystem()
        fs.entries.insert("/repo/.git")
        fs.entries.insert("/repo/Gemfile")
        let project = ProjectDetector(probe: fs).detect(workingDirectory: "/repo")
        XCTAssertEqual(project.manifestKind, .gemfile)
        XCTAssertEqual(project.projectName, "repo")
    }
}
