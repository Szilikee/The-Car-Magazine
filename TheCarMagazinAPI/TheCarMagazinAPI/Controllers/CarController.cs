using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Dapper;
using TheCarMagazinAPI.DTOs;


namespace TheCarMagazinAPI.Controllers
{
    [Route("api/cars")]
    [ApiController]
    public class CarController : ControllerBase
    {
        private readonly string _connectionString = "Server=127.0.0.1;Database=car_database;User ID=root;Password=1234;";

        [HttpGet("brands")]
        public IActionResult GetCarBrands()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                var brands = connection.Query<string>("SELECT DISTINCT Maker FROM cars_info");
                return Ok(brands);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpGet("models")]
        public IActionResult GetCarModels([FromQuery] string brand)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                var query = string.IsNullOrEmpty(brand)
                    ? "SELECT DISTINCT Genmodel FROM cars_info ORDER BY Genmodel ASC"
                    : "SELECT DISTINCT Genmodel FROM cars_info WHERE Maker = @Brand ORDER BY Genmodel ASC";

                var models = connection.Query<string>(query, new { Brand = brand });

                return Ok(models);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpGet("details")]
        public IActionResult GetCarDetails([FromQuery] string brand, [FromQuery] string model, [FromQuery] string trim, [FromQuery] int? year)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                var query = "SELECT * FROM cars_info WHERE Maker = @Brand AND Genmodel = @Model AND Trim = @Trim";
                if (year.HasValue)
                {
                    query += " AND Year = @Year";
                }

                var carDetails = connection.QueryFirstOrDefault<CarDetails>(query, new { Brand = brand, Model = model, Trim = trim, Year = year });

                if (carDetails == null)
                {
                    return NotFound("Car details not found.");
                }

                return Ok(carDetails);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpGet("trims")]
        public IActionResult GetCarTrims([FromQuery] string brand, [FromQuery] string model)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                var trims = connection.Query<string>(
                    "SELECT DISTINCT Trim FROM cars_info WHERE Maker = @Brand AND Genmodel = @Model",
                    new { Brand = brand, Model = model });

                return Ok(trims);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpGet("years")]
        public IActionResult GetCarYears([FromQuery] string brand, [FromQuery] string model, [FromQuery] string trim)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                var years = connection.Query<int>(
                    "SELECT DISTINCT Year FROM cars_info WHERE Maker = @Brand AND Genmodel = @Model AND Trim = @Trim",
                    new { Brand = brand, Model = model, Trim = trim });

                return Ok(years);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpGet("images")]
        public IActionResult GetCarImages([FromQuery] string genmodel_ID)
        {
            if (string.IsNullOrEmpty(genmodel_ID))
            {
                return BadRequest("genmodel_ID is required.");
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                var query = "SELECT Image_ID, Image_name FROM images_info WHERE Genmodel_ID = @GenmodelID";
                var images = connection.Query<CarImage>(query, new { GenmodelID = genmodel_ID });

                return Ok(images);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

    }
}
