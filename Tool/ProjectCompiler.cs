using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.Diagnostics;

namespace Tool;

static class ProjectCompiler
{
    public static async Task<Compilation> Compile(
        Microsoft.CodeAnalysis.Project project,
        CancellationToken cancellationToken)
    {
        AssertNoUnresolvedAnalyzers(project);

        using var analyzerLoadFailureTracker = new AnalyzersLoadFailureTracker(project);

        var compilation = await project.GetCompilationAsync(cancellationToken);

        analyzerLoadFailureTracker.AssertNoLoadFailures();

        return compilation ??
               throw new Exception($"failed to compile {project.FilePath ?? project.Name}");
    }

    static void AssertNoUnresolvedAnalyzers(
        Microsoft.CodeAnalysis.Project project)
    {
        var unresolvedAnalyzers = project
            .AnalyzerReferences
            .OfType<UnresolvedAnalyzerReference>()
            .ToImmutableList();
        if (unresolvedAnalyzers.IsEmpty)
        {
            return;
        }

        var sb = new StringBuilder();
        sb.Append("The following .NET analyzers can't be resolved:");
        foreach (var unresolvedAnalyzer in unresolvedAnalyzers)
        {
            sb.AppendLine();
            sb.Append(" - ");
            sb.Append(unresolvedAnalyzer.FullPath);
        }

        throw new Exception(sb.ToString());
    }

    class AnalyzersLoadFailureTracker : IDisposable
    {
        readonly ImmutableList<AnalyzerLoadFailureTracker> trackers;

        public AnalyzersLoadFailureTracker(
            Microsoft.CodeAnalysis.Project project)
        {
            trackers = project
                .AnalyzerReferences
                .OfType<AnalyzerFileReference>()
                .Select(reference => new AnalyzerLoadFailureTracker(reference))
                .ToImmutableList();
        }

        public void Dispose()
        {
            foreach (var tracker in trackers)
            {
                tracker.Dispose();
            }
        }

        public void AssertNoLoadFailures()
        {
            var relevantFailures = trackers
                .SelectMany(x => x.Failures)
                .Where(x => x.EventArgs.ErrorCode != AnalyzerLoadFailureEventArgs.FailureErrorCode.NoAnalyzers)
                .ToImmutableList();

            if (relevantFailures.IsEmpty)
            {
                return;
            }

            var sb = new StringBuilder();
            sb.Append("The following .NET analyzer loading errors occurred:");
            foreach (var failure in relevantFailures)
            {
                sb.AppendLine();
                sb.Append(" - ");
                sb.AppendLine(failure.Reference.Display);
                sb.Append("   - error: ");
                sb.AppendLine(failure.EventArgs.ErrorCode.ToString());
                sb.Append("   - referenced compiler version: ");
                sb.AppendLine(failure.EventArgs.ReferencedCompilerVersion?.ToString());
                sb.Append("   - message: ");
                sb.Append(failure.EventArgs.Message);
            }

            throw new Exception(sb.ToString());
        }
    }

    class AnalyzerLoadFailureTracker : IDisposable
    {
        readonly AnalyzerFileReference reference;
        readonly List<AnalyzerLoadFailureEventArgs> failures;

        public AnalyzerLoadFailureTracker(
            AnalyzerFileReference reference)
        {
            this.reference = reference;
            failures = new();
            reference.AnalyzerLoadFailed += TrackFailure;
        }

        public ImmutableList<AnalyzerLoadFailure> Failures => failures
            .Select(failure => new AnalyzerLoadFailure(
                reference,
                failure))
            .ToImmutableList();

        void TrackFailure(
            object? sender,
            AnalyzerLoadFailureEventArgs failure)
        {
            failures.Add(failure);
        }

        public void Dispose()
        {
            reference.AnalyzerLoadFailed -= TrackFailure;
        }
    }

    record AnalyzerLoadFailure(
        AnalyzerFileReference Reference,
        AnalyzerLoadFailureEventArgs EventArgs);
}