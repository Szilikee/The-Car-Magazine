using System.Diagnostics;
using System.Text.Json;
using TheCarMagazinAPI.DTOs;


namespace TheCarMagazinAPI.Services
{
    public class ImagePredictionService
    {
        private readonly ILogger<ImagePredictionService> _logger;
        private readonly string _pythonPath = "python"; // Python elérési útja (pl. "C:\\Python39\\python.exe")
        private readonly string _scriptPath = "predict.py"; // Python szkript elérési útja

        public ImagePredictionService(ILogger<ImagePredictionService> logger)
        {
            _logger = logger;
        }

        public async Task<List<PredictionResult>> PredictAsync(Stream imageStream)
        {
            try
            {
                _logger.LogInformation("Starting image prediction.");

                // Ideiglenes fájl mentése a képből
                string tempImagePath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".jpg");
                using (var fileStream = new FileStream(tempImagePath, FileMode.Create, FileAccess.Write))
                {
                    await imageStream.CopyToAsync(fileStream);
                }

                // Python szkript futtatása
                var predictionsJson = await RunPythonScript(tempImagePath);
                var predictions = JsonSerializer.Deserialize<List<PredictionResult>>(predictionsJson, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                if (predictions == null || predictions.Count == 0 || predictions.Any(p => p.Confidence < 0 || p.Confidence > 1))
                {
                    _logger.LogError("Invalid prediction result from Python script.");
                    throw new InvalidOperationException("Invalid prediction result.");
                }

                _logger.LogInformation("Prediction completed successfully.");
                File.Delete(tempImagePath); // Törlés a használat után
                return predictions.OrderByDescending(r => r.Confidence).ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during prediction.");
                throw;
            }
        }

        // New method to handle model selection
        public async Task<List<PredictionResult>> PredictAsync(Stream imageStream, string model)
        {
            try
            {
                _logger.LogInformation($"Starting image prediction for model: {model}");

                string tempImagePath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".jpg");
                using (var fileStream = new FileStream(tempImagePath, FileMode.Create, FileAccess.Write))
                {
                    await imageStream.CopyToAsync(fileStream);
                }

                var predictionsJson = await RunPythonScript(tempImagePath, model);
                var predictions = JsonSerializer.Deserialize<List<PredictionResult>>(
                    predictionsJson,
                    new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                if (predictions == null || predictions.Count == 0 || predictions.Any(p => p.Confidence < 0 || p.Confidence > 1))
                {
                    _logger.LogError("Invalid prediction result from Python script.");
                    throw new InvalidOperationException("Invalid prediction result.");
                }

                _logger.LogInformation("Prediction completed successfully.");
                File.Delete(tempImagePath);
                return predictions.OrderByDescending(r => r.Confidence).ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error during prediction for model {model}.");
                throw;
            }
        }

        private async Task<string> RunPythonScript(string imagePath)
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

            return output.Trim();
        }

        // New method to handle model parameter
        private async Task<string> RunPythonScript(string imagePath, string model)
        {
            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = _pythonPath,
                    Arguments = $"\"{_scriptPath}\" \"{imagePath}\" \"{model}\"",
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

            return output.Trim();
        }
    }

}