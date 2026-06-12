## Problem

Using `MSBuildWorkspace` to open a solution and compile the projects fails to load Razor analyzers, subsequently failing to run source generators for `*.razor` files. The result of this is that some code is missing from the compilation and symbols cannot be resolved.

### History
We've been using this from .net 8 on.
With .net sdk 10.0.300 it's broken as described.
The issue may have occured the first time with .net sdk 10.0.2xx, but at that point we've resolved it by updating `Microsoft.CodeAnalysis*` dependencies to latest version (5.3).

### Workaround
Pin .net sdk to version 10.0.204.

## Use Case
We use a custom dotnet tool to search for usages of our `ILocalizer<T>` interface; usages can be something like:

```
@using System.Globalization
@inject ILocalizer<Default> L

<PageTitle>@L["Feature management"]</PageTitle>
```

Our tool then extracts "Feature management" as a localization template; passing it on to further tooling for translation.
This code analysis/extraction is based on resolving the symbol of the type used by property `L`. This only works when the razor source generators run.

## Repro Structure

- `./Tool` contains the dotnet tool that is using MSBuildWorkspace to open a solution and build it.
- `./SolutionToAnalyze` contains a second solution with the code to compile and analyze.