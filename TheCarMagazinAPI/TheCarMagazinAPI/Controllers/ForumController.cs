using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Dapper;
using TheCarMagazinAPI.Models;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;

namespace TheCarMagazinAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ForumController : ControllerBase
    {
        private readonly string _connectionString = "Server=127.0.0.1;Database=car_database;User ID=root;Password=1234;";

        [HttpGet("brands")]
        public IActionResult GetCarBrands()
        {
            using (var connection = new MySqlConnection(_connectionString))
            {
                connection.Open();
                var brands = connection.Query<string>("SELECT DISTINCT make FROM cars");
                return Ok(brands);
            }
        }

        [HttpGet("models/{brand}")]
        public IActionResult GetCarModels(string brand)
        {
            using (var connection = new MySqlConnection(_connectionString))
            {
                connection.Open();
                var models = connection.Query<string>("SELECT DISTINCT model FROM cars WHERE make = @Brand", new { Brand = brand });
                return Ok(models);
            }
        }

        [HttpGet("years/{brand}/{model}")]
        public IActionResult GetCarYears(string brand, string model)
        {
            using (var connection = new MySqlConnection(_connectionString))
            {
                connection.Open();
                var years = connection.Query<string>("SELECT DISTINCT year FROM cars WHERE make = @Brand AND model = @Model", new { Brand = brand, Model = model });
                return Ok(years);
            }
        }

        [HttpGet("topics")]
        public IActionResult GetForumTopics()
        {
            using (var connection = new MySqlConnection(_connectionString))
            {
                connection.Open();
                var topics = connection.Query<ForumTopic>(
                    "SELECT topic, description, created_at FROM forum_topics"
                );
                return Ok(topics);
            }
        }

        [HttpPost("register")]
        public IActionResult Register([FromBody] UserRegistrationDto userDto)
        {
            if (string.IsNullOrEmpty(userDto.Username) || string.IsNullOrEmpty(userDto.Email) || string.IsNullOrEmpty(userDto.Password))
            {
                return BadRequest("All fields are required.");
            }

            using (var connection = new MySqlConnection(_connectionString))
            {
                connection.Open();

                var existingUser = connection.QueryFirstOrDefault<User>(
                    "SELECT * FROM users WHERE email = @Email", new { Email = userDto.Email });

                if (existingUser != null)
                {
                    return Conflict("A felhasználó már létezik.");
                }

                // Jelszó hashelése
                var hashedPassword = HashPassword(userDto.Password);

                // Felhasználó mentése az adatbázisba
                connection.Execute(
                    "INSERT INTO users (username, email, password) VALUES (@Username, @Email, @Password)",
                    new { Username = userDto.Username, Email = userDto.Email, Password = hashedPassword });
            }

            return CreatedAtAction(nameof(Register), new { email = userDto.Email }, userDto);
        }

        [HttpPost("login")]
        public IActionResult Login([FromBody] UserLoginDto userDto)
        {
            if (string.IsNullOrEmpty(userDto.Email) || string.IsNullOrEmpty(userDto.Password))
            {
                return BadRequest("Email and password are required.");
            }

            using (var connection = new MySqlConnection(_connectionString))
            {
                connection.Open();

                var sql = "SELECT password FROM users WHERE email = @Email";
                var storedPassword = connection.QuerySingleOrDefault<string>(sql, new { Email = userDto.Email });

                if (storedPassword == null || !VerifyPassword(userDto.Password, storedPassword))
                {
                    return Unauthorized("Invalid credentials.");
                }

                return Ok("Login successful.");
            }
        }

        private string HashPassword(string password)
        {
            using (var sha256 = SHA256.Create())
            {
                var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
                return Convert.ToBase64String(bytes);
            }
        }

        private bool VerifyPassword(string enteredPassword, string storedPasswordHash)
        {
            var hashedEnteredPassword = HashPassword(enteredPassword);
            return hashedEnteredPassword == storedPasswordHash;
        }
    }
}
