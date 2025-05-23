using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Dapper;
using TheCarMagazinAPI.Models;
using System.Text.Json;

namespace TheCarMagazinAPI.Controllers
{
    [Route("api/forum")]
    [ApiController]
    public class MarketplaceController : ControllerBase
    {
        private readonly string _connectionString;

        public MarketplaceController(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? "Server=127.0.0.1;Database=car_database;User ID=root;Password=1234;";
            Console.WriteLine($"Connection string: {_connectionString}");
        }

        [HttpGet("carlistings")]
        public IActionResult GetCarListings()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                Console.WriteLine("Database connection opened successfully");

                // Check current database
                var currentDb = connection.Query<string>("SELECT DATABASE()").FirstOrDefault();
                Console.WriteLine($"Current database: {currentDb}");

                // Check available tables
                var tables = connection.Query<string>("SHOW TABLES").ToList();
                Console.WriteLine($"Tables in database: {JsonSerializer.Serialize(tables)}");

                // Explicit query with column aliases
                var carListings = connection.Query<CarListing>(
                    @"SELECT 
                        id AS Id, 
                        name AS Name, 
                        year AS Year, 
                        selling_price AS SellingPrice, 
                        km_driven AS KmDriven, 
                        fuel AS Fuel, 
                        seller_type AS SellerType, 
                        transmission AS Transmission, 
                        owner AS Owner, 
                        image_url AS ImageUrl 
                      FROM car_listings_new");
                Console.WriteLine($"Raw query result: {JsonSerializer.Serialize(carListings)}");

                // Map to DTO
                var carListingsDto = carListings.Select(car => new CarListingDto
                {
                    Id = car.Id,
                    Name = car.Name,
                    Year = car.Year,
                    SellingPrice = car.SellingPrice,
                    KmDriven = car.KmDriven,
                    Fuel = car.Fuel,
                    SellerType = car.SellerType ?? "Unknown",
                    Transmission = car.Transmission,
                    Owner = car.Owner?.Trim() ?? "Unknown",
                    ImageUrl = car.ImageUrl
                }).ToList();
                Console.WriteLine($"DTO result: {JsonSerializer.Serialize(carListingsDto)}");

                return Ok(carListingsDto);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in GetCarListings: {ex.Message}\nStackTrace: {ex.StackTrace}");
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpPost("addcar")]
        public async Task<IActionResult> AddCar([FromBody] CarListing model)
        {
            try
            {
                if (model == null) return BadRequest("Invalid request.");
                if (string.IsNullOrEmpty(model.Name)) return BadRequest("Name is required.");
                if (model.Year <= 0) return BadRequest("Year is required.");
                if (model.SellingPrice <= 0) return BadRequest("Selling price is required.");
                if (model.KmDriven <= 0) return BadRequest("Mileage is required.");
                if (string.IsNullOrEmpty(model.Fuel)) return BadRequest("Fuel type is required.");
                if (string.IsNullOrEmpty(model.SellerType)) return BadRequest("Seller type is required.");
                if (string.IsNullOrEmpty(model.Transmission)) return BadRequest("Transmission is required.");
                if (string.IsNullOrEmpty(model.Owner)) return BadRequest("Owner information is required.");

                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                Console.WriteLine($"Adding car: {JsonSerializer.Serialize(model)}");

                var query = @"INSERT INTO car_listings_new 
                    (name, year, selling_price, km_driven, fuel, seller_type, transmission, owner, image_url) 
                    VALUES (@Name, @Year, @SellingPrice, @KmDriven, @Fuel, @SellerType, @Transmission, @Owner, @ImageUrl)";

                var parameters = new
                {
                    model.Name,
                    model.Year,
                    model.SellingPrice,
                    model.KmDriven,
                    model.Fuel,
                    model.SellerType,
                    model.Transmission,
                    model.Owner,
                    model.ImageUrl
                };

                await connection.ExecuteAsync(query, parameters);
                Console.WriteLine("Car added successfully");
                return Ok(new { message = "Car added successfully!" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in AddCar: {ex.Message}\nStackTrace: {ex.StackTrace}");
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }
    }
}

