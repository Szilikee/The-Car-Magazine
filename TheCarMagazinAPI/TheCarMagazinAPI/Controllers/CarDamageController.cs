using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;
using TheCarMagazinAPI.Services;
using TheCarMagazinAPI.Models;

namespace TheCarMagazinAPI.Controllers
{
    [Route("api/cardamage")]
    [ApiController]
    [Authorize]
    public class CarDamageController : ControllerBase
    {
        private readonly CarDamageService _carDamageService;
        private readonly ILogger<CarDamageController> _logger;

        public CarDamageController(
            CarDamageService carDamageService,
            ILogger<CarDamageController> logger)
        {
            _carDamageService = carDamageService;
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
                var result = await _carDamageService.PredictAsync(stream);
                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing car damage prediction request.");
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