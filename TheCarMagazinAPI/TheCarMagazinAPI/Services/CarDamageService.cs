using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using TheCarMagazinAPI.Models;
using TheCarMagazinAPI.DTOs;


namespace TheCarMagazinAPI.Services
{
    public class CarDamageService
    {
        private readonly ILogger<CarDamageService> _logger;
        private readonly string _pythonPath = "python";
        private readonly string _scriptPath = "cardamage.py";

        public CarDamageService(ILogger<CarDamageService> logger)
        {
            _logger = logger;
        }

        public async Task<CarDamagePredictionResult> PredictAsync(Stream imageStream)
        {
            try
            {
                _logger.LogInformation("Starting car damage prediction.");
                string tempImagePath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + "_image.jpg");
                using (var fileStream = new FileStream(tempImagePath, FileMode.Create, FileAccess.Write))
                {
                    await imageStream.CopyToAsync(fileStream);
                }

                var responseJson = await RunPythonScript(tempImagePath);
                _logger.LogInformation($"Raw Python script response: {responseJson}"); // Log raw JSON

                var response = JsonSerializer.Deserialize<CarDamagePredictionResponse>(
                    responseJson,
                    new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                if (response == null || response.Predictions == null || response.Predictions.Count == 0 ||
                    response.Predictions.Any(p => p.Confidence < 0 || p.Confidence > 1))
                {
                    _logger.LogError("Invalid prediction result from Python script.");
                    throw new InvalidOperationException("Invalid prediction result.");
                }

                _logger.LogInformation("Car damage prediction completed successfully.");
                File.Delete(tempImagePath);

                return new CarDamagePredictionResult
                {
                    Predictions = response.Predictions,
                    AnnotatedImage = response.AnnotatedImage
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during car damage prediction.");
                throw;
            }
        }

        private async Task<string> RunPythonScript(string imagePath)
        {
            try
            {
                var process = new Process
                {
                    StartInfo = new ProcessStartInfo
                    {
                        FileName = _pythonPath,
                        Arguments = $"\"{_scriptPath}\" \"{imagePath}\"",
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    }
                };

                process.Start();
                string output = await process.StandardOutput.ReadToEndAsync();
                string error = await process.StandardError.ReadToEndAsync();
                await process.WaitForExitAsync();

                if (process.ExitCode != 0)
                {
                    _logger.LogError($"Python script failed with error: {error}");
                    throw new Exception($"Python script failed: {error}");
                }

                if (string.IsNullOrWhiteSpace(output))
                {
                    _logger.LogError("Python script returned empty output.");
                    throw new Exception("Python script returned empty output.");
                }

                _logger.LogInformation($"Python script stderr: {error}"); // Log stderr
                return output;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error running Python script: {_scriptPath}.");
                throw;
            }
        }


        private class CarDamagePredictionResponse
        {
            public List<PredictionResult> Predictions { get; set; }
            public string AnnotatedImage { get; set; }
        }
    }
}