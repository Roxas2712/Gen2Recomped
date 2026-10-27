FROM mcr.microsoft.com/dotnet/sdk@sha256:de4fe90a98845d75910b9769662465c84de1a934665c431279d1382b2bddc02b AS build
WORKDIR /source
COPY RetroLegality.csproj packages.lock.json ./
RUN dotnet restore --locked-mode
COPY Program.cs ./
RUN dotnet publish --no-restore -c Release -o /out
FROM mcr.microsoft.com/dotnet/runtime@sha256:a3f9f81954b9c810af2ed18849716c8dc74a4707bd0907fdbd69be81554c0f30
RUN apt-get update && apt-get install -y --no-install-recommends python3 luajit && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /out /checker/
COPY NOTICE LICENSE /checker/
USER 1044:100
ENTRYPOINT ["python3", "/app/tools/bank_legality_worker.py"]
