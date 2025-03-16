using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Dapper;

namespace TheCarMagazinAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class MarketplaceController : ControllerBase
    {
        private readonly string _connectionString = "Server=127.0.0.1;Database=car_database;User ID=root;Password=1234;";

        // ====== Autó hirdetések ======

        [HttpGet("carlistings")]
        public IActionResult GetCarListings()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                // SQL lekérdezés
                var carListings = connection.Query<CarListing>(
                    "SELECT id, name, year, selling_price, km_driven, fuel, seller_type, transmission, owner FROM car_listings");

                // DTO-ként történő visszaadás
                var carListingsDto = carListings.Select(car => new CarListingDto
                {
                    Id = car.Id,
                    Name = car.Name,
                    Year = car.Year,
                    SellingPrice = car.selling_price,
                    KmDriven = car.km_driven,
                    Fuel = car.Fuel,
                    SellerType = car.seller_type ?? "Unknown",
                    Transmission = car.Transmission,
                    Owner = car.Owner?.Trim() ?? "Unknown"
                }).ToList();

                return Ok(carListingsDto);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        // ====== Új autó hirdetés hozzáadása ======

        [HttpPost("addcar")]
        public async Task<IActionResult> AddCar([FromBody] CarListing model)
        {
            try
            {
                // Validáció
                if (model == null)
                    return BadRequest("A kérés érvénytelen.");

                if (string.IsNullOrEmpty(model.Name))
                    return BadRequest("A név megadása kötelező.");

                if (model.Year <= 0)
                    return BadRequest("Az év megadása kötelező.");

                if (model.selling_price <= 0)
                    return BadRequest("Az eladási ár megadása kötelező.");

                if (model.km_driven <= 0)
                    return BadRequest("A futásteljesítmény megadása kötelező.");

                if (string.IsNullOrEmpty(model.Fuel))
                    return BadRequest("Az üzemanyag típusa kötelező.");

                if (string.IsNullOrEmpty(model.seller_type))
                    return BadRequest("Az eladó típusa kötelező.");

                if (string.IsNullOrEmpty(model.Transmission))
                    return BadRequest("A váltó típusa kötelező.");

                if (string.IsNullOrEmpty(model.Owner))
                    return BadRequest("Az előző tulajdonos információja kötelező.");

                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                // SQL lekérdezés
                var query = @"INSERT INTO car_listings (name, year, selling_price, km_driven, fuel, seller_type, transmission, owner) 
                            VALUES (@Name, @Year, @SellingPrice, @KmDriven, @Fuel, @SellerType, @Transmission, @Owner)";

                var parameters = new
                {
                    Name = model.Name,
                    Year = model.Year,
                    SellingPrice = model.selling_price,
                    KmDriven = model.km_driven,
                    Fuel = model.Fuel,
                    SellerType = model.seller_type,
                    Transmission = model.Transmission,
                    Owner = model.Owner
                };

                await connection.ExecuteAsync(query, parameters);
                return Ok(new { message = "Car added successfully!" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"SERVER ERROR: {ex.Message}"); // Konzol log
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }
    }

    // CarListing DTO
    public class CarListing
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public int Year { get; set; }
        public decimal selling_price { get; set; }
        public int km_driven { get; set; }
        public string Fuel { get; set; }
        public string seller_type { get; set; }
        public string Transmission { get; set; }
        public string Owner { get; set; }
    }

    // CarListing DTO (For response)
    public class CarListingDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public int Year { get; set; }
        public decimal SellingPrice { get; set; }
        public int KmDriven { get; set; }
        public string Fuel { get; set; }
        public string SellerType { get; set; }
        public string Transmission { get; set; }
        public string Owner { get; set; }
    }
}
