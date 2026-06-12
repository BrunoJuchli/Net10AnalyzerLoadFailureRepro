using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.CodeAnalysis.MSBuild;

namespace Tool;

public static class Program
{
    public static async Task<int> Main(
        string[] args)
    {
        var solutionPath = args.Single();

        using var workspace = MSBuildWorkspace.Create();

        var solution = await workspace.OpenSolutionAsync(solutionPath);

        var dependencyGraph = solution.GetProjectDependencyGraph();
        var compilations = await dependencyGraph
            .GetTopologicallySortedProjects()
            .Select(projectId =>
                solution.GetProject(projectId)
                ?? throw new Exception($"Failed to get project {projectId} from solution"))
            .ToAsyncEnumerable()
            .Select(async (project, ct) => await ProjectCompiler.Compile(
                project,
                ct))
            .ToListAsync();

        Console.WriteLine($"Successfully compiled {compilations.Count} projects");

        return 0;
    }
}