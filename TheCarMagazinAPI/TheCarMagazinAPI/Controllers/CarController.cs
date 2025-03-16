using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Dapper;

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
                var brands = connection.Query<string>("SELECT DISTINCT make FROM cars");
                return Ok(brands);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        // Update your GetCarModels method to accept a brand
        [HttpGet("models")]
        public IActionResult GetCarModels()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                var models = connection.Query<string>(
                    "SELECT DISTINCT CONCAT(make, ' ', model) AS FullModel FROM cars_info ORDER BY FullModel ASC");

                return Ok(models);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }



        [HttpGet("details")]
        public IActionResult GetCarDetails([FromQuery] string model)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                var carDetails = connection.QueryFirstOrDefault<CarDetails>(
                    "SELECT * FROM cars_info WHERE model = @Model", new { Model = model });

                if (carDetails == null)
                {
                    return NotFound("Car model not found.");
                }

                return Ok(carDetails);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        // CarDetails class for the car information
        public class CarDetails
        {
            public int Id { get; set; }
            public string Make { get; set; }
            public string Model { get; set; }
            public decimal Price { get; set; }
            public int Year { get; set; }
            public decimal Kilometer { get; set; }
            public string FuelType { get; set; }
            public string Transmission { get; set; }
            public string Location { get; set; }
            public string Color { get; set; }
            public string Owner { get; set; }
            public string SellerType { get; set; }
            public string Engine { get; set; }
            public string MaxPower { get; set; }
            public string MaxTorque { get; set; }
            public string Drivetrain { get; set; }
            public decimal Length { get; set; }
            public decimal Width { get; set; }
            public decimal Height { get; set; }
            public decimal SeatingCapacity { get; set; }
            public decimal FuelTankCapacity { get; set; }
        }



    }
}
