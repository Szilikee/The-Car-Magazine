using Dapper;
using MySql.Data.MySqlClient;
using TheCarMagazinAPI.DTOs;

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

        private async Task UpdateUserRank(long userId, MySqlConnection connection)
        {
            var postCount = await connection.QuerySingleAsync<int>(
                "SELECT post_count FROM users WHERE id = @UserId",
                new { UserId = userId });

            string newRank = postCount switch
            {
                >= 50 => "Pit Crew Chief",
                >= 25 => "Track Day Enthusiast",
                >= 10 => "Highway Cruiser",
                >= 5 => "City Driver",
                _ => "Learner Driver"
            };

            await connection.ExecuteAsync(
                "UPDATE users SET user_rank = @UserRank WHERE id = @UserId",
                new { UserRank = newRank, UserId = userId });
        }
    }
}
