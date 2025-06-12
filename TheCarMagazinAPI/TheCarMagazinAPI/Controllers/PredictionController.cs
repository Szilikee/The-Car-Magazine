using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using TheCarMagazinAPI.Services;
using TheCarMagazinAPI.Models;

namespace TheCarMagazinAPI.Controllers
{
    [Route("api/prediction")]
    [ApiController]
    [Authorize]
    public class PredictionController : ControllerBase
    {
        private readonly ImagePredictionService _predictionService;
        private readonly ILogger<PredictionController> _logger;

        public PredictionController(
            ImagePredictionService predictionService,
            ILogger<PredictionController> logger)
        {
            _predictionService = predictionService;
            _logger = logger;
        }

        [HttpPost("predict")]
        public async Task<IActionResult> Predict([FromForm] IFormFile file)
        {
            if (file == null || file.Length == 0)
            {
                _logger.LogWarning("No file uploaded or file is empty.");
                return BadRequest("No file uploaded or file is empty.");
            }
            if (string.IsNullOrEmpty(file.FileName) || !IsImageFile(file.FileName))
            {
                _logger.LogWarning("Invalid file name or format.");
                return BadRequest("Please upload a valid image file (e.g., .jpg, .png).");
            }

            try
            {
                using var stream = file.OpenReadStream();
                var predictions = await _predictionService.PredictAsync(stream);
                return Ok(predictions);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing prediction request.");
                return StatusCode(500, $"Prediction failed: {ex.Message}");
            }
        }

        private bool IsImageFile(string fileName)
        {
            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png" };
            return allowedExtensions.Any(ext => fileName.EndsWith(ext, StringComparison.OrdinalIgnoreCase));
        }
    }
}