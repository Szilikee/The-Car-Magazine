using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Dapper;
using TheCarMagazinAPI.Models;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Security.Cryptography;
using Microsoft.Extensions.Configuration;
using BCrypt.Net;
using Org.BouncyCastle.Crypto.Generators;

namespace TheCarMagazinAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ForumController : ControllerBase
    {
        private readonly string _connectionString;
        private readonly IConfiguration _configuration;

        public ForumController(IConfiguration configuration)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _connectionString = _configuration.GetConnectionString("DefaultConnection");
        }

        // ====== Segédmetódusok ======

        private string HashPassword(string password)
        {
            // Automatically generates the salt and hashes the password with work factor 12
            return BCrypt.Net.BCrypt.HashPassword(password, workFactor: 12);
        }

        private bool VerifyPassword(string enteredPassword, string storedPasswordHash)
        {
            return BCrypt.Net.BCrypt.Verify(enteredPassword, storedPasswordHash);
        }


        private string GenerateJwtToken(User user)
        {
            var secretKey = _configuration["AppSettings:Secret"];
            if (string.IsNullOrEmpty(secretKey))
                throw new InvalidOperationException("JWT Secret key is not configured.");

            var claims = new[]
            {
                new Claim(ClaimTypes.Name, user.Username),
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString())
            };

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

        private int GetUserIdFromToken()
        {
            var identity = HttpContext.User.Identity as ClaimsIdentity;
            var userIdClaim = identity?.FindFirst(ClaimTypes.NameIdentifier);
            return userIdClaim != null ? int.Parse(userIdClaim.Value) : throw new UnauthorizedAccessException("User ID not found in token.");
        }

        // ====== Felhasználó kezelés ======

        [HttpPost("register")]
        public IActionResult Register([FromBody] UserRegistrationDto userDto)
        {
            if (userDto == null || string.IsNullOrWhiteSpace(userDto.Username) ||
                string.IsNullOrWhiteSpace(userDto.Email) || string.IsNullOrWhiteSpace(userDto.Password))
                return BadRequest("All fields are required.");

            using var connection = new MySqlConnection(_connectionString);
            connection.Open();

            var existingUser = connection.QueryFirstOrDefault<User>("SELECT * FROM users WHERE email = @Email", new { userDto.Email });
            if (existingUser != null)
                return Conflict("A user with this email already exists.");

            var hashedPassword = HashPassword(userDto.Password);
            var userId = connection.ExecuteScalar<int>(
                "INSERT INTO users (username, email, password) VALUES (@Username, @Email, @Password); SELECT LAST_INSERT_ID();",
                new { userDto.Username, userDto.Email, Password = hashedPassword });

            var user = new User { Id = userId, Username = userDto.Username };
            var token = GenerateJwtToken(user);

            return CreatedAtAction(nameof(Register), new { userId }, new { Token = token, UserID = userId });
        }

        [HttpPost("login")]
        public IActionResult Login([FromBody] UserLoginDto userDto)
        {
            if (userDto == null || string.IsNullOrWhiteSpace(userDto.Email) || string.IsNullOrWhiteSpace(userDto.Password))
                return BadRequest("Email and password are required.");

            using var connection = new MySqlConnection(_connectionString);
            connection.Open();

            var user = connection.QueryFirstOrDefault<User>("SELECT id, username, password, language FROM users WHERE email = @Email", new { userDto.Email });
            if (user == null || !VerifyPassword(userDto.Password, user.Password))
                return Unauthorized("Invalid credentials.");

            var token = GenerateJwtToken(user);
            return Ok(new { Token = token, UserID = user.Id, Language = "en" });
        }

        /*

        [HttpGet("brands")]
        public IActionResult GetCarBrands()
        {
            using var connection = new MySqlConnection(_connectionString);
            var brands = connection.Query<string>("SELECT DISTINCT make FROM cars");
            return Ok(brands);
        }

        [HttpGet("models/{brand}")]
        public IActionResult GetCarModels(string brand)
        {
            using var connection = new MySqlConnection(_connectionString);
            var models = connection.Query<string>("SELECT DISTINCT model FROM cars WHERE make = @Brand", new { Brand = brand });
            return Ok(models);
        }

        [HttpGet("years/{brand}/{model}")]
        public IActionResult GetCarYears(string brand, string model)
        {
            using var connection = new MySqlConnection(_connectionString);
            var years = connection.Query<string>("SELECT DISTINCT year FROM cars WHERE make = @Brand AND model = @Model", new { Brand = brand, Model = model });
            return Ok(years);
        }*/

        [HttpGet("topics")]
        public IActionResult GetForumTopics()
        {
            using var connection = new MySqlConnection(_connectionString);
            var topics = connection.Query<ForumTopic>("SELECT topic, description, created_at FROM forum_topics");
            return Ok(topics);
        }

        [HttpPost("userdetails/update")]
        public IActionResult UpdateUserDetails([FromBody] UserDetailsDto userDetailsDto)
        {
            using var connection = new MySqlConnection(_connectionString);
            var rowsAffected = connection.Execute("UPDATE users SET bio = @Bio, status = @Status WHERE id = @UserId",
                new { userDetailsDto.UserId, userDetailsDto.Bio, userDetailsDto.Status });

            return rowsAffected > 0 ? Ok(new { message = "Profile updated successfully!" }) : NotFound("User not found.");
        }

        [HttpGet("userdetails/{userId}")]
        public IActionResult GetUserDetails(int userId)
        {
            using var connection = new MySqlConnection(_connectionString);
            var userDetails = connection.QueryFirstOrDefault("SELECT id, username, email, bio, status FROM users WHERE id = @UserId", new { UserId = userId });
            return userDetails != null ? Ok(userDetails) : NotFound("User not found.");
        }
    }
}