using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Dapper;
using TheCarMagazinAPI.Models;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using TheCarMagazinAPI.Services;
using System.Text.Json;


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

        // ====== Segédmetódusok ======

        // Jelszó hash-elése SHA256 segítségével
        private string HashPassword(string password)
        {
            using var sha256 = SHA256.Create();
            var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
            return Convert.ToBase64String(bytes);
        }

        // Jelszó ellenőrzése
        private bool VerifyPassword(string enteredPassword, string storedPasswordHash)
        {
            var hashedEnteredPassword = HashPassword(enteredPassword);
            return hashedEnteredPassword == storedPasswordHash;
        }

        // JWT token generálása
        private string GenerateJwtToken(User user)
        {
            var secretKey = _configuration["AppSettings:Secret"];
            if (string.IsNullOrEmpty(secretKey))
                throw new InvalidOperationException("JWT Secret key is not configured.");

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

        // ====== Felhasználó kezelése ======

        [HttpPost("register")]
        public IActionResult Register([FromBody] UserRegistrationDto userDto)
        {
            if (userDto == null || string.IsNullOrWhiteSpace(userDto.Username) ||
                string.IsNullOrWhiteSpace(userDto.Email) || string.IsNullOrWhiteSpace(userDto.Password))
            {
                return BadRequest("All fields are required.");
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                // Email ellenőrzése
                var existingUser = connection.QueryFirstOrDefault<User>(
                    "SELECT * FROM users WHERE email = @Email", new { userDto.Email });

                if (existingUser != null)
                    return Conflict("A user with this email already exists.");

                // Felhasználó létrehozása
                var hashedPassword = HashPassword(userDto.Password);
                var userId = connection.ExecuteScalar<int>(
                    @"INSERT INTO users (username, email, password) 
                      VALUES (@Username, @Email, @Password);
                      SELECT LAST_INSERT_ID();",
                    new { userDto.Username, userDto.Email, Password = hashedPassword });

                // Token generálás
                var user = new User { Id = userId, Username = userDto.Username };
                var token = GenerateJwtToken(user);

                return CreatedAtAction(nameof(Register), new { userId }, new { Token = token, UserID = userId });
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
                return BadRequest("Email and password are required.");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                var user = connection.QueryFirstOrDefault<User>(
                    "SELECT id, username, password FROM users WHERE email = @Email",
                    new { userDto.Email });

                if (user == null || !VerifyPassword(userDto.Password, user.Password))
                    return Unauthorized("Invalid credentials.");

                var token = GenerateJwtToken(user);
                return Ok(new { Token = token, UserID = user.Id });
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        // ====== Fórum funkciók ======

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
                var models = connection.Query<string>(
                    "SELECT DISTINCT model FROM cars WHERE make = @Brand", new { Brand = brand });
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
                var years = connection.Query<string>(
                    "SELECT DISTINCT year FROM cars WHERE make = @Brand AND model = @Model",
                    new { Brand = brand, Model = model });
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
                    "SELECT topic, description, created_at FROM forum_topics");
                return Ok(topics);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        // Update user profile details (bio, status)
        [HttpPost("userdetails/update")]
        public IActionResult UpdateUserDetails([FromBody] UserDetailsDto userDetailsDto)
        {
            if (userDetailsDto == null || userDetailsDto.UserId <= 0)
            {
                return BadRequest("Invalid user data.");
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                connection.Open();

                // Update user bio and status
                var rowsAffected = connection.Execute(
                    @"UPDATE users 
              SET bio = @Bio, status = @Status 
              WHERE id = @UserId",
                    new { userDetailsDto.UserId, userDetailsDto.Bio, userDetailsDto.Status });

                if (rowsAffected > 0)
                {
                    return Ok(new { message = "Profile updated successfully!" });
                }
                else
                {
                    return NotFound("User not found.");
                }
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

                // Felhasználó adatainak lekérése
                var query = "SELECT id, username, email, bio, status FROM users WHERE id = @UserId";
                var userDetails = connection.QueryFirstOrDefault(query, new { UserId = userId });

                if (userDetails == null)
                {
                    return NotFound("User not found.");
                }

                return Ok(userDetails); // Visszaadja a felhasználó adatokat
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }

        }
    


    }
}
