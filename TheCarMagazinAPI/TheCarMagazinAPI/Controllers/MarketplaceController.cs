using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Dapper;
using TheCarMagazinAPI.DTOs;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace TheCarMagazinAPI.Controllers
{
    [Route("api/marketplace")]
    [ApiController]
    public class MarketplaceController : ControllerBase
    {
        private readonly string _connectionString;

        public MarketplaceController(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new ArgumentNullException("Connection string not found");
        }

        private long GetUserIdFromToken()
        {
            var identity = HttpContext.User.Identity as ClaimsIdentity;
            var userIdClaim = identity?.FindFirst(ClaimTypes.NameIdentifier);
            return userIdClaim != null ? long.Parse(userIdClaim.Value) : throw new UnauthorizedAccessException("User ID not found in token.");
        }

        [HttpGet("carlistings")]
        public async Task<IActionResult> GetCarListings()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var query = @"SELECT 
                        id AS Id, 
                        user_id AS UserId,
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

                var carListings = await connection.QueryAsync<CarListing>(query);

                var carListingsDto = carListings.Select(car => new CarListingDto
                {
                    Id = car.Id,
                    UserId = car.UserId,
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

        [HttpGet("my-listings")]
        [Authorize]
        public async Task<IActionResult> GetMyCarListings()
        {
            try
            {
                long userId = GetUserIdFromToken();

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var query = @"SELECT 
                        id AS Id, 
                        user_id AS UserId,
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
                      FROM car_listings_new
                      WHERE user_id = @UserId";

                var carListings = await connection.QueryAsync<CarListing>(query, new { UserId = userId });

                var carListingsDto = carListings.Select(car => new CarListingDto
                {
                    Id = car.Id,
                    UserId = car.UserId,
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
            catch (UnauthorizedAccessException ex)
            {
                return Unauthorized(ex.Message);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpPost("addcar")]
        [Authorize]
        public async Task<IActionResult> AddCar([FromBody] CarListing model)
        {
            try
            {
                long userId = GetUserIdFromToken();
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
                await connection.OpenAsync();
                Console.WriteLine($"Adding car: {JsonSerializer.Serialize(model)}");

                var query = @"INSERT INTO car_listings_new 
                    (user_id, name, year, selling_price, km_driven, fuel, seller_type, transmission, contact, 
                     image_url, image_url2, image_url3, image_url4, image_url5, vin, engine_capacity, horsepower, 
                     body_type, color, number_of_doors, condition_, steering_side, registration_status, description) 
                    VALUES (@UserId, @Name, @Year, @SellingPrice, @KmDriven, @Fuel, @SellerType, @Transmission, 
                            @Contact, @ImageUrl, @ImageUrl2, @ImageUrl3, @ImageUrl4, @ImageUrl5, @Vin, @EngineCapacity, 
                            @Horsepower, @BodyType, @Color, @NumberOfDoors, @condition_, @SteeringSide, @RegistrationStatus, @Description);
                    SELECT LAST_INSERT_ID();";

                var newId = await connection.ExecuteScalarAsync<long>(query, new
                {
                    UserId = userId,
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
            catch (UnauthorizedAccessException ex)
            {
                return Unauthorized(ex.Message);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in AddCar: {ex.Message}\nStackTrace: {ex.StackTrace}");
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }

        [HttpPut("carlistings/{id}")]
        [Authorize]
        public async Task<IActionResult> UpdateCarListing(long id, [FromBody] CarListing model)
        {
            try
            {
                long userId = GetUserIdFromToken();
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
                await connection.OpenAsync();

                // Verify the listing belongs to the user
                var listingOwnerId = await connection.ExecuteScalarAsync<long?>(
                    "SELECT user_id FROM car_listings_new WHERE id = @Id",
                    new { Id = id });

                if (listingOwnerId == null)
                    return NotFound("Listing not found.");

                if (listingOwnerId != userId)
                    return Forbid("You can only update your own listings.");

                var query = @"UPDATE car_listings_new 
                    SET name = @Name, 
                        year = @Year, 
                        selling_price = @SellingPrice, 
                        km_driven = @KmDriven, 
                        fuel = @Fuel, 
                        seller_type = @SellerType, 
                        transmission = @Transmission, 
                        contact = @Contact, 
                        image_url = @ImageUrl, 
                        image_url2 = @ImageUrl2, 
                        image_url3 = @ImageUrl3, 
                        image_url4 = @ImageUrl4, 
                        image_url5 = @ImageUrl5, 
                        vin = @Vin, 
                        engine_capacity = @EngineCapacity, 
                        horsepower = @Horsepower, 
                        body_type = @BodyType, 
                        color = @Color, 
                        number_of_doors = @NumberOfDoors, 
                        condition_ = @condition_, 
                        steering_side = @SteeringSide, 
                        registration_status = @RegistrationStatus, 
                        description = @Description
                    WHERE id = @Id";

                var rowsAffected = await connection.ExecuteAsync(query, new
                {
                    Id = id,
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

                if (rowsAffected == 0)
                    return StatusCode(500, "Failed to update listing.");

                return Ok(new { message = "Car listing updated successfully!" });
            }
            catch (UnauthorizedAccessException ex)
            {
                return Unauthorized(ex.Message);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in UpdateCarListing: {ex.Message}\nStackTrace: {ex.StackTrace}");
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }

        [HttpDelete("carlistings/{id}")]
        [Authorize]
        public async Task<IActionResult> DeleteCarListing(long id)
        {
            try
            {
                long userId = GetUserIdFromToken();

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                // Verify the listing belongs to the user
                var listingOwnerId = await connection.ExecuteScalarAsync<long?>(
                    "SELECT user_id FROM car_listings_new WHERE id = @Id",
                    new { Id = id });

                if (listingOwnerId == null)
                    return NotFound("Listing not found.");

                if (listingOwnerId != userId)
                    return Forbid("You can only delete your own listings.");

                var query = "DELETE FROM car_listings_new WHERE id = @Id";
                var rowsAffected = await connection.ExecuteAsync(query, new { Id = id });

                if (rowsAffected == 0)
                    return StatusCode(500, "Failed to delete listing.");

                return Ok(new { message = "Car listing deleted successfully!" });
            }
            catch (UnauthorizedAccessException ex)
            {
                return Unauthorized(ex.Message);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in DeleteCarListing: {ex.Message}\nStackTrace: {ex.StackTrace}");
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }
    }
}