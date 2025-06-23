using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using MySql.Data.MySqlClient;
using Newtonsoft.Json;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using TheCarMagazinAPI.DTOs;
using TheCarMagazinAPI.Models;
using TheCarMagazinAPI.Services;

namespace TheCarMagazinAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class UserController : ControllerBase
    {
        private readonly string _connectionString;
        private readonly IConfiguration _configuration;
        private readonly IEmailService _emailService;
        public UserController(IConfiguration configuration, IEmailService emailService)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _connectionString = _configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Database connection string is missing");
            _emailService = emailService;
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

        private string HashPasswordArgon2(string password)
        {
            var argon2 = new Konscious.Security.Cryptography.Argon2id(Encoding.UTF8.GetBytes(password))
            {
                DegreeOfParallelism = 4,
                MemorySize = 131072,
                Iterations = 6
            };
            var salt = new byte[16];
            using (var rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(salt);
            }
            argon2.Salt = salt;
            var hash = argon2.GetBytes(32);
            return $"$argon2id$v=19$m={argon2.MemorySize},t={argon2.Iterations},p={argon2.DegreeOfParallelism}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
        }

        private bool VerifyPasswordArgon2(string enteredPassword, string storedHash)
        {
            try
            {
                var parts = storedHash.Split('$');
                if (parts.Length != 6 || parts[1] != "argon2id" || parts[2] != "v=19")
                {
                    Console.WriteLine($"Invalid Argon2 hash format: {storedHash}");
                    return false;
                }

                var parameters = parts[3].Split(',');
                int memorySize = int.Parse(parameters[0].Split('=')[1]);
                int iterations = int.Parse(parameters[1].Split('=')[1]);
                int parallelism = int.Parse(parameters[2].Split('=')[1]);

                var salt = Convert.FromBase64String(parts[4]);
                var storedHashBytes = Convert.FromBase64String(parts[5]);

                var argon2 = new Konscious.Security.Cryptography.Argon2id(Encoding.UTF8.GetBytes(enteredPassword))
                {
                    DegreeOfParallelism = parallelism,
                    MemorySize = memorySize,
                    Iterations = iterations,
                    Salt = salt
                };

                var computedHash = argon2.GetBytes(storedHashBytes.Length);
                return computedHash.SequenceEqual(storedHashBytes);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"VerifyPasswordArgon2 error: StoredHash={storedHash}, Error={ex.Message}");
                return false;
            }
        }

        private async Task<string> GenerateJwtToken(User user)
        {
            var secretKey = _configuration["AppSettings:Secret"];
            if (string.IsNullOrEmpty(secretKey))
                throw new InvalidOperationException("JWT Secret key is not configured.");

            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();
            var role = await connection.QuerySingleOrDefaultAsync<string>(
                "SELECT role FROM users WHERE id = @Id", new { user.Id }) ?? "user";

            var claims = new[]
            {
                new Claim(ClaimTypes.Name, user.Username),
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Role, role)
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

        private long GetUserIdFromToken()
        {
            var identity = HttpContext.User.Identity as ClaimsIdentity;
            var userIdClaim = identity?.FindFirst(ClaimTypes.NameIdentifier);
            return userIdClaim != null ? long.Parse(userIdClaim.Value) : throw new UnauthorizedAccessException("User ID not found in token.");
        }

        private string GenerateVerificationCode()
        {
            const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            var randomBytes = new byte[5];
            using (var rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(randomBytes);
            }
            char[] code = new char[5];
            for (int i = 0; i < 5; i++)
            {
                code[i] = chars[randomBytes[i] % chars.Length];
            }
            return new string(code);
        }

        // User Management

        [HttpPost("register-argon2")]
        public async Task<IActionResult> RegisterArgon2([FromBody] UserRegistrationDto userDto)
        {
            if (userDto == null || string.IsNullOrWhiteSpace(userDto.Username) ||
                string.IsNullOrWhiteSpace(userDto.Email) || string.IsNullOrWhiteSpace(userDto.Password))
                return BadRequest("All fields are required.");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var existingUser = await connection.QueryFirstOrDefaultAsync<User>(
                    "SELECT * FROM users WHERE email = @Email OR username = @Username",
                    new { userDto.Email, userDto.Username });
                if (existingUser != null)
                    return Conflict("A user with this email or username already exists.");

                var hashedPassword = HashPasswordArgon2(userDto.Password);
                var verificationCode = GenerateVerificationCode();

                var userId = await connection.ExecuteScalarAsync<long>(
                    @"INSERT INTO users (username, email, password, role, VerificationCode, VerificationCodeExpiry, IsVerified, HashingAlgorithm) 
              VALUES (@Username, @Email, @Password, @Role, @VerificationCode, @VerificationCodeExpiry, @IsVerified, @HashingAlgorithm); 
              SELECT LAST_INSERT_ID();",
                    new
                    {
                        userDto.Username,
                        userDto.Email,
                        Password = hashedPassword,
                        Role = "user",
                        VerificationCode = verificationCode,
                        VerificationCodeExpiry = DateTime.UtcNow.AddMinutes(15), 
                        IsVerified = false,
                        UserRank = "Learner Driver", // Új mező
                        HashingAlgorithm = "Argon2id" // Explicit Argon2id beállítás

                    });

                var emailBody = $"Your verification code is: {verificationCode}. It is valid for 15 minutes.";
                await _emailService.SendEmailAsync(userDto.Email, "Verify Your Email - The Car Magazine", emailBody);

                return CreatedAtAction(nameof(RegisterArgon2), new { userId }, new { message = "Verification code sent to your email.", UserId = userId });
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

     

        [HttpPost("verify")]
        public async Task<IActionResult> VerifyCode([FromBody] VerifyCodeDto verifyDto)
        {
            if (verifyDto == null || string.IsNullOrWhiteSpace(verifyDto.Code) || verifyDto.UserId <= 0)
                return BadRequest("Invalid request.");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var user = await connection.QueryFirstOrDefaultAsync<User>(
                    "SELECT * FROM users WHERE Id = @UserId",
                    new { UserId = verifyDto.UserId });

                if (user == null)
                    return NotFound("User not found.");

                if (user.IsVerified)
                    return BadRequest("User is already verified.");

                if (user.VerificationCode != verifyDto.Code)
                    return BadRequest("Invalid verification code.");

                if (user.VerificationCodeExpiry < DateTime.UtcNow)
                    return BadRequest("Verification code has expired.");

                await connection.ExecuteAsync(
                    "UPDATE users SET IsVerified = @IsVerified, VerificationCode = NULL, VerificationCodeExpiry = NULL WHERE Id = @UserId",
                    new { IsVerified = true, UserId = verifyDto.UserId });

                var token = await GenerateJwtToken(user);

                return Ok(new { Token = token, UserId = user.Id });
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
            {
                Console.WriteLine("Login failed: Username or password is missing.");
                return BadRequest(new { error = "Username and password are required." });
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var user = await connection.QueryFirstOrDefaultAsync<User>(
                    "SELECT id, username, password, language, role, IsVerified, HashingAlgorithm, isBanned FROM users WHERE username = @Username",
                    new { Username = userDto.Username.Trim() });

                if (user == null)
                {
                    Console.WriteLine($"Login failed: User not found for username={userDto.Username}");
                    return Unauthorized(new { error = "Invalid credentials." });
                }

                if (user.IsBanned)
                {
                    Console.WriteLine($"Login failed: User is banned, username={userDto.Username}");
                    return Unauthorized(new { error = "Your account is banned." });
                }

                Console.WriteLine($"Login attempt: Username={userDto.Username}, HashingAlgorithm={user.HashingAlgorithm ?? "None"}");

                bool isPasswordValid;
                switch (user.HashingAlgorithm)
                {
                    case "Argon2id":
                        isPasswordValid = VerifyPasswordArgon2(userDto.Password, user.Password);
                        break;
                    case "BCrypt":
                        isPasswordValid = VerifyPassword(userDto.Password, user.Password);
                        break;
                    default:
                        Console.WriteLine($"Login failed: Invalid or missing HashingAlgorithm={user.HashingAlgorithm ?? "None"} for username={userDto.Username}");
                        return Unauthorized(new { error = "Invalid credentials." });
                }

                if (!isPasswordValid)
                {
                    Console.WriteLine($"Login failed: Password verification failed for username={userDto.Username}");
                    return Unauthorized(new { error = "Invalid credentials." });
                }

                if (!user.IsVerified)
                {
                    Console.WriteLine($"Login failed: Email not verified for username={userDto.Username}");
                    return Unauthorized(new { error = "Email not verified. Please verify your email before logging in." });
                }

                await connection.ExecuteAsync(
                    "UPDATE users SET last_activity = CURRENT_TIMESTAMP WHERE id = @Id",
                    new { user.Id });

                var token = await GenerateJwtToken(user);
                return Ok(new { token, userID = user.Id, username = user.Username, language = user.Language ?? "en" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Login error: Username={userDto.Username}, Error={ex.Message}, StackTrace={ex.StackTrace}");
                return StatusCode(500, new { error = $"Server error: {ex.Message}" });
            }
        }

        [HttpPost("userdetails/update")]
        [Authorize]
        public async Task<IActionResult> UpdateUserDetails([FromBody] UserDetailsDto userDetailsDto)
        {
            try
            {
                long currentUserId = GetUserIdFromToken();
                if (currentUserId != userDetailsDto.UserId)
                    return Forbid("You can only update your own profile.");

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var rowsAffected = await connection.ExecuteAsync(
                    @"UPDATE users 
                      SET bio = @Bio, 
                          status = @Status, 
                          profile_image_url = @ProfileImageUrl,
                          location = @Location,
                          social_media_links = @SocialMediaLinks,
                          user_rank = @UserRank,
                          signature = @Signature,
                          personal_links = @PersonalLinks,
                          hobbies = @Hobbies
                      WHERE id = @UserId",
                    new
                    {
                        userDetailsDto.UserId,
                        userDetailsDto.Bio,
                        userDetailsDto.Status,
                        userDetailsDto.ProfileImageUrl,
                        userDetailsDto.Location,
                        userDetailsDto.ContactEmail,
                        SocialMediaLinks = userDetailsDto.SocialMediaLinks != null ? JsonConvert.SerializeObject(userDetailsDto.SocialMediaLinks) : null,
                        userDetailsDto.UserRank,
                        userDetailsDto.Signature,
                        PersonalLinks = userDetailsDto.PersonalLinks != null ? JsonConvert.SerializeObject(userDetailsDto.PersonalLinks) : null,
                        Hobbies = userDetailsDto.Hobbies != null ? JsonConvert.SerializeObject(userDetailsDto.Hobbies) : null
                    });

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
        [AllowAnonymous]
        public async Task<IActionResult> GetUserDetails(long userId)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var userDetails = await connection.QueryFirstOrDefaultAsync(
                    @"SELECT CAST(id AS SIGNED) AS id, username, email, bio, status, profile_image_url,
                     location, social_media_links,
                     registration_date, post_count, last_activity,
                     user_rank, signature, personal_links, hobbies
              FROM users WHERE id = @UserId",
                    new { UserId = userId });

                if (userDetails == null)
                    return NotFound("User not found.");

                var result = new UserDetailsDto
                {
                    UserId = userDetails.id,
                    Username = userDetails.username,
                    Email = userDetails.email,
                    Bio = userDetails.bio,
                    Status = userDetails.status,
                    ProfileImageUrl = userDetails.profile_image_url,
                    Location = userDetails.location,
                    SocialMediaLinks = !string.IsNullOrEmpty(userDetails.social_media_links)
                        ? JsonConvert.DeserializeObject<Dictionary<string, string>>(userDetails.social_media_links)
                        : null,
                    RegistrationDate = userDetails.registration_date,
                    PostCount = userDetails.post_count,
                    LastActivity = userDetails.last_activity,
                    UserRank = userDetails.user_rank,
                    Signature = userDetails.signature,
                    PersonalLinks = !string.IsNullOrEmpty(userDetails.personal_links)
                        ? JsonConvert.DeserializeObject<Dictionary<string, string>>(userDetails.personal_links)
                        : null,
                    Hobbies = !string.IsNullOrEmpty(userDetails.hobbies)
                        ? JsonConvert.DeserializeObject<List<string>>(userDetails.hobbies)
                        : null
                };

                return Ok(result);
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

        [HttpGet("userdetails/{userId}/top-posts")]
        [Authorize]
        public async Task<IActionResult> GetTopPosts(long userId)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var topPosts = await connection.QueryAsync(
                    @"SELECT id, content, created_at
                      FROM posts 
                      WHERE user_id = @UserId 
                      ORDER BY created_at DESC 
                      LIMIT 10",
                    new { UserId = userId });

                return Ok(topPosts);
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

        [HttpGet("me")]
        [Authorize]
        public async Task<IActionResult> GetCurrentUser()
        {
            try
            {
                var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
                if (string.IsNullOrEmpty(userIdClaim) || !long.TryParse(userIdClaim, out var userId))
                {
                    return Unauthorized(new { error = "Invalid user token" });
                }

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                var user = await connection.QuerySingleOrDefaultAsync(
                    "SELECT id, username, email, role FROM users WHERE id = @UserId",
                    new { UserId = userId });

                if (user == null)
                {
                    return NotFound(new { error = "User not found" });
                }

                return Ok(new
                {
                    id = user.id,
                    username = user.username,
                    email = user.email,
                    role = user.role
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = "Failed to fetch user", details = ex.Message });
            }
        }

        [HttpPost("password/change/request")]
        public async Task<IActionResult> InitiatePasswordChange([FromBody] PasswordChangeRequestDto requestDto)
        {
            try
            {
                long currentUserId = requestDto.UserId;
                if (currentUserId != requestDto.UserId)
                    return Forbid("You can only change your own password.");

                if (string.IsNullOrWhiteSpace(requestDto.NewPassword))
                    return BadRequest("New password is required.");

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    var user = await connection.QueryFirstOrDefaultAsync<User>(
                        "SELECT id, email FROM users WHERE id = @UserId",
                        new { UserId = requestDto.UserId },
                        transaction);

                    if (user == null)
                    {
                        await transaction.RollbackAsync();
                        Console.WriteLine($"Hiba: Felhasználó nem található, UserId: {requestDto.UserId}");
                        return NotFound("User not found.");
                    }

                    var verificationCode = GenerateVerificationCode();
                    var requestId = Guid.NewGuid().ToString();

                    Console.WriteLine($"Generált requestId: {requestId}, VerificationCode: {verificationCode}, UserId: {requestDto.UserId}");

                    int rowsAffected = await connection.ExecuteAsync(
                        @"UPDATE users 
                SET password_change_code = @VerificationCode, 
                    password_change_expiry = @VerificationCodeExpiry,
                    password_change_request_id = @RequestId,
                    pending_password = @PendingPassword,
                    HashingAlgorithm = 'Argon2id'
                WHERE id = @UserId",
                        new
                        {
                            UserId = requestDto.UserId,
                            VerificationCode = verificationCode,
                            VerificationCodeExpiry = DateTime.UtcNow.AddMinutes(15),
                            RequestId = requestId,
                            PendingPassword = HashPasswordArgon2(requestDto.NewPassword)
                        },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        Console.WriteLine($"Hiba: Az UPDATE nem érintett sort, UserId: {requestDto.UserId}");
                        return StatusCode(500, "Failed to update user data in database.");
                    }

                    var updatedUser = await connection.QuerySingleOrDefaultAsync<dynamic>(
                        @"SELECT password_change_request_id, password_change_code, password_change_expiry 
                FROM users WHERE id = @UserId",
                        new { UserId = requestDto.UserId },
                        transaction);

                    if (updatedUser == null || updatedUser.password_change_request_id != requestId || updatedUser.password_change_code != verificationCode)
                    {
                        await transaction.RollbackAsync();
                        Console.WriteLine($"Hiba: Mentett adatok nem egyeznek. Adatbázis requestId: {updatedUser?.password_change_request_id}, Elvárt: {requestId}, Adatbázis kód: {updatedUser?.password_change_code}, Elvárt: {verificationCode}");
                        return StatusCode(500, "Failed to verify saved data.");
                    }

                    Console.WriteLine($"Mentett requestId az adatbázisban: {updatedUser.password_change_request_id}, Kód: {updatedUser.password_change_code}, Lejárat: {updatedUser.password_change_expiry}");

                    var emailBody = $"Your password change verification code is: {verificationCode}. It is valid for 15 minutes.";
                    await _emailService.SendEmailAsync(user.Email, "Password Change Verification - The Car Magazine", emailBody);

                    await transaction.CommitAsync();

                    return Ok(new { message = "Verification code sent to your email.", requestId });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    Console.WriteLine($"Tranzakciós hiba: {ex.Message}, StackTrace: {ex.StackTrace}");
                    return StatusCode(500, $"Transaction error: {ex.Message}");
                }
            }
            catch (UnauthorizedAccessException ex)
            {
                Console.WriteLine($"Jogosultsági hiba: {ex.Message}");
                return Unauthorized(ex.Message);
            }
            catch (MySqlException ex)
            {
                Console.WriteLine($"MySQL hiba: {ex.Message}, ErrorCode: {ex.Number}");
                return StatusCode(500, $"Database error: {ex.Message}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Általános hiba: {ex.Message}, StackTrace: {ex.StackTrace}");
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpPost("password/change/verify")]
        [Authorize]
        public async Task<IActionResult> VerifyAndChangePassword([FromBody] PasswordChangeVerifyDto verifyDto)
        {
            try
            {
                long currentUserId = GetUserIdFromToken();
                if (currentUserId != verifyDto.UserId)
                    return Forbid("You can only verify your own password change.");

                if (string.IsNullOrWhiteSpace(verifyDto.Code) || string.IsNullOrWhiteSpace(verifyDto.RequestId) || string.IsNullOrWhiteSpace(verifyDto.NewPassword))
                    return BadRequest("Verification code, request ID, and new password are required.");

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    var user = await connection.QuerySingleOrDefaultAsync<dynamic>(
                        @"SELECT id, password_change_code, password_change_expiry, 
                  password_change_request_id, pending_password, HashingAlgorithm
                  FROM users WHERE id = @UserId",
                        new { UserId = verifyDto.UserId },
                        transaction);

                    if (user == null)
                    {
                        await transaction.RollbackAsync();
                        Console.WriteLine($"Hiba: Felhasználó nem található, UserId: {verifyDto.UserId}");
                        return NotFound("User not found.");
                    }

                    Console.WriteLine($"Kliens requestId: {verifyDto.RequestId}, Adatbázis requestId: {user.password_change_request_id}");
                    Console.WriteLine($"Kliens kód: {verifyDto.Code}, Adatbázis kód: {user.password_change_code}, Lejárat: {user.password_change_expiry}");

                    if (user.password_change_request_id != verifyDto.RequestId)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Invalid request ID.");
                    }

                    if (user.password_change_code != verifyDto.Code)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Invalid verification code.");
                    }

                    if (user.password_change_expiry < DateTime.UtcNow)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Verification code has expired.");
                    }

                    // Ellenőrizzük, hogy a pending_password megfelel-e az új jelszónak
                    bool isPendingPasswordValid = user.HashingAlgorithm == "Argon2id"
                        ? VerifyPasswordArgon2(verifyDto.NewPassword, user.pending_password)
                        : VerifyPassword(verifyDto.NewPassword, user.pending_password);

                    if (!isPendingPasswordValid)
                    {
                        await transaction.RollbackAsync();
                        Console.WriteLine($"Hiba: Az új jelszó nem egyezik a pending_password hash-ével, UserId: {verifyDto.UserId}");
                        return BadRequest("New password does not match the pending password.");
                    }

                    string newPasswordHash = user.HashingAlgorithm == "Argon2id"
                        ? HashPasswordArgon2(verifyDto.NewPassword)
                        : HashPassword(verifyDto.NewPassword);

                    int rowsAffected = await connection.ExecuteAsync(
                        @"UPDATE users 
                  SET password = @NewPasswordHash,
                      HashingAlgorithm = @HashingAlgorithm,
                      password_change_code = NULL,
                      password_change_expiry = NULL,
                      password_change_request_id = NULL,
                      pending_password = NULL
                  WHERE id = @UserId",
                        new
                        {
                            UserId = verifyDto.UserId,
                            NewPasswordHash = newPasswordHash,
                            HashingAlgorithm = user.HashingAlgorithm // Tartsuk meg az eredeti algoritmust
                        },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        Console.WriteLine($"Hiba: Az UPDATE nem érintett sort, UserId: {verifyDto.UserId}");
                        return StatusCode(500, "Failed to update user password.");
                    }

                    await transaction.CommitAsync();

                    Console.WriteLine($"Sikeres jelszóváltoztatás, új hash: {newPasswordHash}");

                    return Ok(new { message = "Password changed successfully!" });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    Console.WriteLine($"Tranzakciós hiba: {ex.Message}, StackTrace: {ex.StackTrace}");
                    return StatusCode(500, $"Transaction error: {ex.Message}");
                }
            }
            catch (UnauthorizedAccessException ex)
            {
                Console.WriteLine($"Jogosultsági hiba: {ex.Message}");
                return Unauthorized(ex.Message);
            }
            catch (MySqlException ex)
            {
                Console.WriteLine($"MySQL hiba: {ex.Message}, ErrorCode: {ex.Number}");
                return StatusCode(500, $"Database error: {ex.Message}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Általános hiba: {ex.Message}, StackTrace: {ex.StackTrace}");
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        // Új végpont a kapcsolatfelvételi üzenet kezelésére
        [HttpPost("support/message")]
        public async Task<IActionResult> CreateSupportTicket([FromBody] CreateSupportTicketDto dto)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var userId = dto.UserId != null ? int.Parse(dto.UserId) : (int?)null;
                var username = dto.Username ?? "Not Specified";

                await connection.ExecuteAsync(
                    @"INSERT INTO support_messages (user_id, username, email, subject, message, submitted_at, status)
              VALUES (@UserId, @Username, @Email, @Subject, @Message, @SubmittedAt, 'new')",
                    new
                    {
                        UserId = userId,
                        Username = username,
                        Email = dto.Email,
                        Subject = dto.Subject,
                        Message = dto.Message,
                        SubmittedAt = DateTime.UtcNow
                    });

                return Ok(new { message = "Support ticket created successfully." });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpPost("ticket")]
        [Authorize]
        public async Task<IActionResult> SubmitSupportTicket([FromBody] SubmitTicketDto ticketDto)
        {
            if (ticketDto == null ||
                string.IsNullOrWhiteSpace(ticketDto.Username) ||
                string.IsNullOrWhiteSpace(ticketDto.Email) ||
                string.IsNullOrWhiteSpace(ticketDto.Message))
            {
                return BadRequest(new { error = "Username, email, and message are required." });
            }

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                // Felhasználó létezésének ellenőrzése
                var existingUser = await connection.QueryFirstOrDefaultAsync(
                    "SELECT id FROM users WHERE id = @UserId AND username = @Username AND email = @Email",
                    new { UserId = ticketDto.UserId, Username = ticketDto.Username, Email = ticketDto.Email });

                if (existingUser == null)
                {
                    return BadRequest(new { error = "Invalid user data." });
                }

                // Support ticket mentése
                var query = @"
            INSERT INTO support_messages (user_id, username, email, subject, message, status, submitted_at)
            VALUES (@UserId, @Username, @Email, @Subject, @Message, 'new', NOW())";

                var rowsAffected = await connection.ExecuteAsync(query, new
                {
                    ticketDto.UserId,
                    ticketDto.Username,
                    ticketDto.Email,
                    ticketDto.Subject,
                    ticketDto.Message
                });

                if (rowsAffected == 0)
                {
                    return StatusCode(500, new { error = "Failed to submit ticket." });
                }

                // E-mail értesítés küldése a felhasználónak
                var emailSubject = "Support Ticket Received";
                var emailBody = $@"Dear {ticketDto.Username},

We have received your support ticket with the subject: {ticketDto.Subject}.
Our team will review your request and respond as soon as possible.

Thank you for contacting us,
The Car Magazine Support Team";

                await _emailService.SendEmailAsync(ticketDto.Email, emailSubject, emailBody);

                return Ok(new { message = "Support ticket submitted successfully." });
            }
            catch (MySqlException ex)
            {
                Console.WriteLine($"MySQL error: {ex.Message}, ErrorCode: {ex.Number}");
                return StatusCode(500, new { error = $"Database error: {ex.Message}" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"General error: {ex.Message}, StackTrace: {ex.StackTrace}");
                return StatusCode(500, new { error = $"An error occurred: {ex.Message}" });
            }
        }

        [HttpPost("email/change/request")]
        public async Task<IActionResult> InitiateEmailChange([FromBody] EmailChangeRequestDto requestDto)
        {
            try
            {
                //long currentUserId = GetUserIdFromToken();
                long currentUserId = requestDto.UserId;
                if (currentUserId != requestDto.UserId)
                    return Unauthorized("You can only change your own email.");

                if (string.IsNullOrWhiteSpace(requestDto.NewEmail))
                    return BadRequest("New email is required.");

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    var user = await connection.QueryFirstOrDefaultAsync<User>(
                        "SELECT id, email FROM users WHERE id = @UserId",
                        new { UserId = requestDto.UserId },
                        transaction);

                    if (user == null)
                    {
                        await transaction.RollbackAsync();
                        return NotFound("User not found.");
                    }

                    if (user.Email == requestDto.NewEmail)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("New email must be different from the current email.");
                    }

                    var existingUser = await connection.QueryFirstOrDefaultAsync<User>(
                        "SELECT id FROM users WHERE email = @Email AND id != @UserId",
                        new { Email = requestDto.NewEmail, UserId = requestDto.UserId },
                        transaction);

                    if (existingUser != null)
                    {
                        await transaction.RollbackAsync();
                        return Conflict("This email is already in use by another user.");
                    }

                    var verificationCode = GenerateVerificationCode();
                    var requestId = Guid.NewGuid().ToString();

                    int rowsAffected = await connection.ExecuteAsync(
                        @"UPDATE users 
                  SET email_change_code = @VerificationCode, 
                      email_change_expiry = @VerificationCodeExpiry,
                      email_change_request_id = @RequestId,
                      pending_email = @PendingEmail
                  WHERE id = @UserId",
                        new
                        {
                            UserId = requestDto.UserId,
                            VerificationCode = verificationCode,
                            VerificationCodeExpiry = DateTime.UtcNow.AddMinutes(15),
                            RequestId = requestId,
                            PendingEmail = requestDto.NewEmail
                        },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        return StatusCode(500, "Failed to update user data in database.");
                    }

                    var emailBody = $"Your email change verification code is: {verificationCode}. It is valid for 15 minutes.";
                    await _emailService.SendEmailAsync(requestDto.NewEmail, "Email Change Verification - The Car Magazine", emailBody);

                    await transaction.CommitAsync();

                    return Ok(new { message = "Verification code sent to your new email.", requestId });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    return StatusCode(500, $"Transaction error: {ex.Message}");
                }
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

        [HttpPost("email/change/verify")]
        [Authorize]
        public async Task<IActionResult> VerifyAndChangeEmail([FromBody] EmailChangeVerifyDto verifyDto)
        {
            try
            {
                long currentUserId = GetUserIdFromToken();
                if (currentUserId != verifyDto.UserId)
                    return Unauthorized("You can only verify your own email change.");

                if (string.IsNullOrWhiteSpace(verifyDto.Code) || string.IsNullOrWhiteSpace(verifyDto.RequestId) || string.IsNullOrWhiteSpace(verifyDto.NewEmail))
                    return BadRequest("Verification code, request ID, and new email are required.");

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    var user = await connection.QuerySingleOrDefaultAsync<dynamic>(
                        @"SELECT id, email_change_code, email_change_expiry, 
                         email_change_request_id, pending_email
                  FROM users WHERE id = @UserId",
                        new { UserId = verifyDto.UserId },
                        transaction);

                    if (user == null)
                    {
                        await transaction.RollbackAsync();
                        return NotFound("User not found.");
                    }

                    if (user.email_change_request_id != verifyDto.RequestId)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Invalid request ID.");
                    }

                    if (user.email_change_code != verifyDto.Code)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Invalid verification code.");
                    }

                    if (user.email_change_expiry < DateTime.UtcNow)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Verification code has expired.");
                    }

                    if (user.pending_email != verifyDto.NewEmail)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("New email does not match the pending email.");
                    }

                    int rowsAffected = await connection.ExecuteAsync(
                        @"UPDATE users 
                  SET email = @NewEmail,
                      email_change_code = NULL,
                      email_change_expiry = NULL,
                      email_change_request_id = NULL,
                      pending_email = NULL
                  WHERE id = @UserId",
                        new
                        {
                            UserId = verifyDto.UserId,
                            NewEmail = verifyDto.NewEmail
                        },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        return StatusCode(500, "Failed to update user email.");
                    }

                    await transaction.CommitAsync();

                    return Ok(new { message = "Email changed successfully!" });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    return StatusCode(500, $"Transaction error: {ex.Message}");
                }
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

        [HttpPost("posts")]
        [Authorize]
        public async Task<IActionResult> CreatePost([FromBody] CreatePostDto postDto)
        {
            try
            {
                long userId = GetUserIdFromToken(); // Extract user ID from JWT token
                if (userId != postDto.UserId)
                    return Forbid("You can only create posts for your own account.");

                if (string.IsNullOrWhiteSpace(postDto.Content))
                    return BadRequest("Post content is required.");

                if (postDto.SubtopicId <= 0)
                    return BadRequest("Valid subtopic ID is required.");

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    // Verify subtopic exists
                    var subtopicExists = await connection.ExecuteScalarAsync<int>(
                        "SELECT COUNT(*) FROM subtopics WHERE id = @SubtopicId",
                        new { SubtopicId = postDto.SubtopicId },
                        transaction);
                    if (subtopicExists == 0)
                    {
                        await transaction.RollbackAsync();
                        return BadRequest("Subtopic does not exist.");
                    }

                    // Verify parent_post_id exists (if provided)
                    if (postDto.ParentPostId.HasValue && postDto.ParentPostId.Value > 0)
                    {
                        var parentExists = await connection.ExecuteScalarAsync<int>(
                            "SELECT COUNT(*) FROM posts WHERE id = @ParentPostId",
                            new { ParentPostId = postDto.ParentPostId.Value },
                            transaction);
                        if (parentExists == 0)
                        {
                            await transaction.RollbackAsync();
                            return BadRequest("Parent post does not exist.");
                        }
                    }

                    // Insert the new post into the posts table
                    var postId = await connection.ExecuteScalarAsync<long>(
                        @"INSERT INTO posts (user_id, subtopic_id, content, created_at, parent_post_id, upvote_count, downvote_count)
                  VALUES (@UserId, @SubtopicId, @Content, @CreatedAt, @ParentPostId, @UpvoteCount, @DownvoteCount);
                  SELECT LAST_INSERT_ID();",
                        new
                        {
                            UserId = postDto.UserId,
                            SubtopicId = postDto.SubtopicId,
                            Content = postDto.Content,
                            CreatedAt = DateTime.UtcNow,
                            ParentPostId = postDto.ParentPostId,
                            UpvoteCount = 0,
                            DownvoteCount = 0
                        },
                        transaction);

                    // Increment the post_count in the users table
                    var rowsAffected = await connection.ExecuteAsync(
                        @"UPDATE users 
                  SET post_count = post_count + 1
                  WHERE id = @UserId",
                        new { UserId = postDto.UserId },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        return StatusCode(500, "Failed to update post count.");
                    }

                    await transaction.CommitAsync();

                    return CreatedAtAction(nameof(GetTopPosts), new { userId = postDto.UserId }, new { PostId = postId, Message = "Post created successfully." });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    return StatusCode(500, $"Transaction error: {ex.Message}");
                }
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


        [HttpPost("sync-post-count")]
        [Authorize(Roles = "admin")] // Restrict to admin users
        public async Task<IActionResult> SyncPostCount()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var rowsAffected = await connection.ExecuteAsync(
                    @"UPDATE users u
              SET post_count = (
                  SELECT COUNT(*) 
                  FROM posts p 
                  WHERE p.user_id = u.id
              )");

                return Ok(new { Message = $"{rowsAffected} users' post counts updated." });
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

        [HttpDelete("posts/{postId}")]
        [Authorize]
        public async Task<IActionResult> DeletePost(long postId)
        {
            try
            {
                long userId = GetUserIdFromToken(); // Extract user ID from JWT token

                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    // Verify the post exists and belongs to the user
                    var postOwnerId = await connection.ExecuteScalarAsync<long?>(
                        "SELECT user_id FROM posts WHERE id = @PostId",
                        new { PostId = postId },
                        transaction);

                    if (postOwnerId == null)
                    {
                        await transaction.RollbackAsync();
                        return NotFound("Post not found.");
                    }

                    if (postOwnerId != userId)
                    {
                        await transaction.RollbackAsync();
                        return Forbid("You can only delete your own posts.");
                    }

                    // Check if the post has child posts (replies)
                    var hasChildren = await connection.ExecuteScalarAsync<int>(
                        "SELECT COUNT(*) FROM posts WHERE parent_post_id = @PostId",
                        new { PostId = postId },
                        transaction);

                    if (hasChildren > 0)
                    {
                        // Option 1: Prevent deletion if there are replies
                        await transaction.RollbackAsync();
                        return BadRequest("Cannot delete post with replies.");
                        // Option 2: Delete child posts recursively (uncomment to use)
                        /*
                        await connection.ExecuteAsync(
                            "DELETE FROM posts WHERE parent_post_id = @PostId",
                            new { PostId = postId },
                            transaction);
                        */
                    }

                    // Delete the post
                    var rowsAffected = await connection.ExecuteAsync(
                        "DELETE FROM posts WHERE id = @PostId",
                        new { PostId = postId },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        return StatusCode(500, "Failed to delete post.");
                    }

                    // Decrement post_count in the users table
                    rowsAffected = await connection.ExecuteAsync(
                        @"UPDATE users 
                  SET post_count = post_count - 1
                  WHERE id = @UserId AND post_count > 0",
                        new { UserId = userId },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        return StatusCode(500, "Failed to update post count.");
                    }

                    await transaction.CommitAsync();
                    return Ok(new { Message = "Post deleted successfully." });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    return StatusCode(500, $"Transaction error: {ex.Message}");
                }
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



    }



}  

