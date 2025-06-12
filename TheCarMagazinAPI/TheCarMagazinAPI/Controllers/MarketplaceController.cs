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
                ?? throw new ArgumentNullException("Connection string not found");
        }

        [HttpGet("carlistings")]
        public IActionResult GetCarListings()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                var currentDb = connection.Query<string>("SELECT DATABASE()").FirstOrDefault();

                var tables = connection.Query<string>("SHOW TABLES").ToList();

                var query = @"SELECT 
                        id AS Id, 
                        name AS Name, 
                        year AS Year, 
                        selling_price AS SellingPrice, 
                        km_driven AS KmDriven, 
                        fuel AS Fuel, 
                        seller_type AS SellerType, 
                        transmission AS Transmission, 
                        contact AS Contact, 
                        IFNULL(image_url, '') AS ImageUrl,
                        IFNULL(image_url2, '') AS ImageUrl2,
                        IFNULL(image_url3, '') AS ImageUrl3,
                        IFNULL(image_url4, '') AS ImageUrl4,
                        IFNULL(image_url5, '') AS ImageUrl5,
                        IFNULL(vin, '') AS Vin,
                        IFNULL(engine_capacity, NULL) AS EngineCapacity,
                        IFNULL(horsepower, NULL) AS Horsepower,
                        IFNULL(body_type, '') AS BodyType,
                        IFNULL(color, '') AS Color,
                        IFNULL(number_of_doors, NULL) AS NumberOfDoors,
                        IFNULL(condition_, '') AS condition_,
                        IFNULL(steering_side, '') AS SteeringSide,
                        IFNULL(registration_status, '') AS RegistrationStatus,
                        IFNULL(description, '') AS Description
                      FROM car_listings_new";

                var carListings = connection.Query<CarListing>(query);

                var carListingsDto = carListings.Select(car => new CarListingDto
                {
                    Id = car.Id,
                    Name = car.Name,
                    Year = car.Year,
                    SellingPrice = car.SellingPrice,
                    KmDriven = car.KmDriven,
                    Fuel = car.Fuel,
                    SellerType = car.SellerType,
                    Transmission = car.Transmission,
                    Contact = car.Contact,
                    ImageUrl = car.ImageUrl,
                    ImageUrl2 = car.ImageUrl2,
                    ImageUrl3 = car.ImageUrl3,
                    ImageUrl4 = car.ImageUrl4,
                    ImageUrl5 = car.ImageUrl5,
                    Vin = car.Vin,
                    EngineCapacity = car.EngineCapacity,
                    Horsepower = car.Horsepower,
                    BodyType = car.BodyType,
                    Color = car.Color,
                    NumberOfDoors = car.NumberOfDoors,
                    condition_ = car.condition_,
                    SteeringSide = car.SteeringSide,
                    RegistrationStatus = car.RegistrationStatus,
                    Description = car.Description
                }).ToList();

                return Ok(carListingsDto);
            }
            catch (Exception ex)
            {
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
                if (string.IsNullOrEmpty(model.Contact)) return BadRequest("Contact information is required.");

                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                Console.WriteLine($"Adding car: {JsonSerializer.Serialize(model)}");

                var query = @"INSERT INTO car_listings_new 
                    (name, year, selling_price, km_driven, fuel, seller_type, transmission, contact, 
                     image_url, image_url2, image_url3,image_url4, image_url5, vin, engine_capacity, horsepower, body_type, color, number_of_doors, 
                     condition_, steering_side, registration_status, description) 
                    VALUES (@Name, @Year, @SellingPrice, @KmDriven, @Fuel, @SellerType, @Transmission, 
                            @Contact, @ImageUrl, @ImageUrl2, @ImageUrl3, @ImageUrl4, @ImageUrl5, @Vin, @EngineCapacity, @Horsepower, @BodyType, @Color, 
                            @NumberOfDoors, @condition_, @SteeringSide, @RegistrationStatus, @Description);
                    SELECT LAST_INSERT_ID();";

                var newId = await connection.ExecuteScalarAsync<int>(query, new
                {
                    model.Name,
                    model.Year,
                    model.SellingPrice,
                    model.KmDriven,
                    model.Fuel,
                    model.SellerType,
                    model.Transmission,
                    model.Contact,
                    model.ImageUrl,
                    model.ImageUrl2,
                    model.ImageUrl3,
                    model.ImageUrl4,
                    model.ImageUrl5,
                    model.Vin,
                    model.EngineCapacity,
                    model.Horsepower,
                    model.BodyType,
                    model.Color,
                    model.NumberOfDoors,
                    model.condition_,
                    model.SteeringSide,
                    model.RegistrationStatus,
                    model.Description
                });
                Console.WriteLine($"Car added successfully with ID: {newId}");
                return Ok(new { message = "Car added successfully!", id = newId });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in AddCar: {ex.Message}\nStackTrace: {ex.StackTrace}");
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }
    }
}