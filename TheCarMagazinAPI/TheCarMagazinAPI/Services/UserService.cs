using Dapper;
using MySql.Data.MySqlClient;
using TheCarMagazinAPI.Models;
using Microsoft.Extensions.Configuration;

namespace TheCarMagazinAPI.Services
{
    public class UserService
    {
        private readonly string _connectionString;

        public UserService(IConfiguration configuration)
        {
            _connectionString = configuration["ConnectionStrings:Default"];
        }

        public User RegisterUser(UserRegistrationDto userDto, string hashedPassword)
        {
            using var connection = new MySqlConnection(_connectionString);
            connection.Open();

            // Ellenőrizze, hogy létezik-e már felhasználó
            var existingUser = connection.QueryFirstOrDefault<User>(
                "SELECT * FROM users WHERE email = @Email", new { userDto.Email });

            if (existingUser != null)
                throw new InvalidOperationException("A felhasználó már létezik.");

            // Új felhasználó hozzáadása
            var userId = connection.ExecuteScalar<int>(
                @"INSERT INTO users (username, email, password) 
                  VALUES (@Username, @Email, @Password);
                  SELECT LAST_INSERT_ID();",
                new { userDto.Username, userDto.Email, Password = hashedPassword });

            return new User { Id = userId, Username = userDto.Username };
        }

        public User GetUserByEmail(string email)
        {
            using var connection = new MySqlConnection(_connectionString);
            connection.Open();

            return connection.QueryFirstOrDefault<User>(
                "SELECT id, username, password FROM users WHERE email = @Email", new { email });
        }

        public User GetUserById(int userId)
        {
            using var connection = new MySqlConnection(_connectionString);
            connection.Open();

            return connection.QueryFirstOrDefault<User>(
                "SELECT id, username, email, bio, status FROM users WHERE id = @UserId", new { userId });
        }

        public int UpdateUserDetails(int userId, string bio, string status)
        {
            using var connection = new MySqlConnection(_connectionString);
            connection.Open();

            var rowsAffected = connection.Execute(
                @"UPDATE users 
                SET bio = @Bio, status = @Status 
                WHERE id = @UserId",
                new { userId, bio, status });

            return rowsAffected;
        }
    }
}
