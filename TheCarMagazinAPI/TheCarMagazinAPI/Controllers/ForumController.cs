using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Dapper;
using TheCarMagazinAPI.Models;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Security.Cryptography;

namespace TheCarMagazinAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ForumController : ControllerBase
    {
        private readonly string _connectionString = "Server=127.0.0.1;Database=car_database;User ID=root;Password=1234;";
        private readonly IConfiguration _configuration;

        public ForumController(IConfiguration configuration)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
        }

        // JWT Token generálás
        private string GenerateJwtToken(User user)
        {
            var secretKey = _configuration["AppSettings:Secret"];
            if (string.IsNullOrEmpty(secretKey))
            {
                throw new InvalidOperationException("JWT Secret key is not configured.");
            }

            var claims = new[] { new Claim(ClaimTypes.Name, user.Username) };
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                issuer: _configuration["AppSettings:Issuer"],
                audience: _configuration["AppSettings:Audience"],
                claims: claims,
                expires: DateTime.UtcNow.AddHours(1),
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }


        [HttpPost("register")]
        public IActionResult Register([FromBody] UserRegistrationDto userDto)
        {

            if (userDto == null || string.IsNullOrWhiteSpace(userDto.Username) || string.IsNullOrWhiteSpace(userDto.Email) || string.IsNullOrWhiteSpace(userDto.Password))
            {
                return BadRequest("All fields are required.");
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                // Ellenőrizzük, hogy már létezik-e a felhasználó email címe
                var existingUser = connection.QueryFirstOrDefault<User>(
                    "SELECT * FROM users WHERE email = @Email", new { Email = userDto.Email });

                if (existingUser != null)
                {
                    return Conflict("A user with this email already exists.");
                }

                var hashedPassword = HashPassword(userDto.Password);

                // Felhasználó létrehozása az adatbázisban
                var userId = connection.ExecuteScalar<int>(
                    "INSERT INTO users (username, email, password) VALUES (@Username, @Email, @Password); SELECT LAST_INSERT_ID();",
                    new { Username = userDto.Username, Email = userDto.Email, Password = hashedPassword });

                // Miután létrehoztuk a felhasználót, generáljuk a JWT tokent
                var user = new User { Id = userId, Username = userDto.Username };
                var token = GenerateJwtToken(user);

                // Válasz visszaküldése a tokennel és a userID-val
                return CreatedAtAction(nameof(Register), new { userId = userId }, new { Token = token, UserID = userId });
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpPost("login")]
        public IActionResult Login([FromBody] UserLoginDto userDto)
        {
            if (userDto == null || string.IsNullOrWhiteSpace(userDto.Email) || string.IsNullOrWhiteSpace(userDto.Password))
            {
                return BadRequest("Email and password are required.");
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                var sql = "SELECT id, username, password FROM users WHERE email = @Email";
                var storedUser = connection.QuerySingleOrDefault<User>(sql, new { Email = userDto.Email });

                if (storedUser == null || !VerifyPassword(userDto.Password, storedUser.Password))
                {
                    return Unauthorized("Invalid credentials.");
                }

                var token = GenerateJwtToken(storedUser);

                if (string.IsNullOrEmpty(token))
                {
                    return StatusCode(500, "Failed to generate token.");
                }

                // Válaszban szerepelni fog a Token és UserID
                return Ok(new { Token = token, UserID = storedUser.Id });
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }



        [HttpGet("userdetails/{userId}")]
        public IActionResult GetUserDetails(int userId)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                var sql = "SELECT * FROM users WHERE id = @UserId";
                var userDetails = connection.QueryFirstOrDefault<User>(sql, new { UserId = userId });

                if (userDetails == null)
                {
                    return NotFound("User details not found.");
                }

                return Ok(userDetails);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpPost("userdetails/update")]
        public IActionResult UpdateUserDetails([FromBody] User user)
        {
            if (user == null)
            {
                return BadRequest("Invalid data.");
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                // Frissítés
                connection.Execute(
                    "UPDATE users SET profile_image_url = @ProfileImageUrl, created_topics_count = @CreatedTopicsCount, " +
                    "last_login = @LastLogin, bio = @Bio, status = @Status WHERE id = @UserId",
                    user);

                return NoContent(); // Success
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

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

        [HttpGet("models/{brand}")]
        public IActionResult GetCarModels(string brand)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                var models = connection.Query<string>("SELECT DISTINCT model FROM cars WHERE make = @Brand", new { Brand = brand });
                return Ok(models);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpGet("years/{brand}/{model}")]
        public IActionResult GetCarYears(string brand, string model)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                var years = connection.Query<string>("SELECT DISTINCT year FROM cars WHERE make = @Brand AND model = @Model", new { Brand = brand, Model = model });
                return Ok(years);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpGet("topics")]
        public IActionResult GetForumTopics()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();
                var topics = connection.Query<ForumTopic>(
                    "SELECT topic, description, created_at FROM forum_topics"
                );
                return Ok(topics);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        private string HashPassword(string password)
        {
            using var sha256 = SHA256.Create();
            var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
            return Convert.ToBase64String(bytes);
        }

        private bool VerifyPassword(string enteredPassword, string storedPasswordHash)
        {
            var hashedEnteredPassword = HashPassword(enteredPassword);
            return hashedEnteredPassword == storedPasswordHash;
        }
    }
}
