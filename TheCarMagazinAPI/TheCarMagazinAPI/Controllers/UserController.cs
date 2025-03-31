using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Dapper;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Configuration;
using BCrypt.Net;
using System.Threading.Tasks;
using TheCarMagazinAPI.Models;

namespace TheCarMagazinAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class UserController : ControllerBase
    {
        private readonly string _connectionString;
        private readonly IConfiguration _configuration;

        public UserController(IConfiguration configuration)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _connectionString = _configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Database connection string is missing");
        }

        // Helper Methods

        private string HashPassword(string password)
        {
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

        private long GetUserIdFromToken() // Changed to long
        {
            var identity = HttpContext.User.Identity as ClaimsIdentity;
            var userIdClaim = identity?.FindFirst(ClaimTypes.NameIdentifier);
            return userIdClaim != null ? long.Parse(userIdClaim.Value) : throw new UnauthorizedAccessException("User ID not found in token.");
        }

        // User Management

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] UserRegistrationDto userDto)
        {
            if (userDto == null || string.IsNullOrWhiteSpace(userDto.Username) ||
                string.IsNullOrWhiteSpace(userDto.Email) || string.IsNullOrWhiteSpace(userDto.Password))
                return BadRequest("All fields are required.");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var existingUser = await connection.QueryFirstOrDefaultAsync<User>(
                    "SELECT * FROM users WHERE email = @Email", new { userDto.Email });
                if (existingUser != null)
                    return Conflict("A user with this email already exists.");

                var hashedPassword = HashPassword(userDto.Password);
                var userId = await connection.ExecuteScalarAsync<long>( // Changed to long
                    "INSERT INTO users (username, email, password) VALUES (@Username, @Email, @Password); SELECT LAST_INSERT_ID();",
                    new { userDto.Username, userDto.Email, Password = hashedPassword });

                var user = new User { Id = userId, Username = userDto.Username };
                var token = GenerateJwtToken(user);

                return CreatedAtAction(nameof(Register), new { userId }, new { Token = token, UserID = userId });
            }
            catch (MySqlException ex)
            {
                return StatusCode(500, $"Database error: {ex.Message}");
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] UserLoginDto userDto)
        {
            if (userDto == null || string.IsNullOrWhiteSpace(userDto.Username) || string.IsNullOrWhiteSpace(userDto.Password))
                return BadRequest("Username and password are required.");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var user = await connection.QueryFirstOrDefaultAsync<User>(
                    "SELECT id, username, password, language FROM users WHERE username = @Username",
                    new { userDto.Username });
                if (user == null || !VerifyPassword(userDto.Password, user.Password))
                    return Unauthorized("Invalid credentials.");

                var token = GenerateJwtToken(user);
                return Ok(new { Token = token, UserID = user.Id, Username = user.Username, Language = user.Language }); // Use DB language
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Error: {ex.Message}");
            }
        }

        [HttpPost("userdetails/update")]
        [Authorize]
        public async Task<IActionResult> UpdateUserDetails([FromBody] UserDetailsDto userDetailsDto)
        {
            try
            {
                long currentUserId = GetUserIdFromToken(); // Changed to long
                if (currentUserId != userDetailsDto.UserId)
                    return Forbid("You can only update your own profile.");

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var rowsAffected = await connection.ExecuteAsync(
                    "UPDATE users SET bio = @Bio, status = @Status WHERE id = @UserId",
                    new { userDetailsDto.UserId, userDetailsDto.Bio, userDetailsDto.Status });

                return rowsAffected > 0
                    ? Ok(new { message = "Profile updated successfully!" })
                    : NotFound("User not found.");
            }
            catch (UnauthorizedAccessException ex)
            {
                return Unauthorized(ex.Message);
            }
            catch (MySqlException ex)
            {
                return StatusCode(500, $"Database error: {ex.Message}");
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpGet("userdetails/{userId}")]
        [Authorize]
        public async Task<IActionResult> GetUserDetails(long userId) // Changed to long
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var userDetails = await connection.QueryFirstOrDefaultAsync(
                    "SELECT id, username, email, bio, status FROM users WHERE id = @UserId",
                    new { UserId = userId });
                return userDetails != null ? Ok(userDetails) : NotFound("User not found.");
            }
            catch (MySqlException ex)
            {
                return StatusCode(500, $"Database error: {ex.Message}");
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }
    }
}