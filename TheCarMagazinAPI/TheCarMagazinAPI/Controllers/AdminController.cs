using Dapper;
using Konscious.Security.Cryptography;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using Newtonsoft.Json;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using TheCarMagazinAPI.Models;
using TheCarMagazinAPI.DTOs;


namespace TheCarMagazinAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(Roles = "admin")]
    public class AdminController : ControllerBase
    {
        private readonly string _connectionString;
        private readonly IConfiguration _configuration;
        private readonly TheCarMagazinAPI.Services.IEmailService _emailService;

        public AdminController(IConfiguration configuration, TheCarMagazinAPI.Services.IEmailService emailService)
        {
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _emailService = emailService ?? throw new ArgumentNullException(nameof(emailService));
            _connectionString = _configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Database connection string is missing");
        }

        // Hashing helper methods
        private string HashPasswordBcrypt(string password)
        {
            return BCrypt.Net.BCrypt.HashPassword(password, workFactor: 12);
        }

        private string HashPasswordArgon2(string password)
        {
            var argon2 = new Argon2id(Encoding.UTF8.GetBytes(password))
            {
                DegreeOfParallelism = 4,
                MemorySize = 65536,
                Iterations = 4
            };
            var salt = new byte[16];
            using (var rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(salt);
            }
            argon2.Salt = salt;
            var hash = argon2.GetBytes(32);
            var saltAndHash = new byte[salt.Length + hash.Length];
            Buffer.BlockCopy(salt, 0, saltAndHash, 0, salt.Length);
            Buffer.BlockCopy(hash, 0, saltAndHash, salt.Length, hash.Length);
            return Convert.ToBase64String(saltAndHash);
        }

        [HttpGet("health")]
        [AllowAnonymous]
        public IActionResult HealthCheck()
        {
            return Ok(new { status = "API is running" });
        }

        [HttpGet("user")]
        public async Task<IActionResult> GetUser([FromQuery] long? id, [FromQuery] string? username)
        {
            if (id == null && string.IsNullOrEmpty(username))
                return BadRequest(new { error = "User ID or Username is required" });

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                string query = id != null
                    ? @"SELECT id, username, email, bio, status, profile_image_url, location, 
                           social_media_links, registration_date, post_count, last_activity, user_rank, 
                           signature, personal_links, hobbies, role, IsVerified, language, HashingAlgorithm, isBanned
                        FROM users WHERE id = @UserId"
                    : @"SELECT id, username, email, bio, status, profile_image_url, location, 
                           social_media_links, registration_date, post_count, last_activity, user_rank, 
                           signature, personal_links, hobbies, role, IsVerified, language, HashingAlgorithm, isBanned
                        FROM users WHERE username = @Username";

                var user = await connection.QueryFirstOrDefaultAsync(
                    query,
                    new { UserId = id, Username = username });

                if (user == null)
                    return NotFound(new { error = "User not found" });

                var result = new
                {
                    user.id,
                    user.username,
                    user.email,
                    user.bio,
                    user.status,
                    user.profile_image_url,
                    user.location,
                    SocialMediaLinks = !string.IsNullOrEmpty(user.social_media_links)
                        ? JsonConvert.DeserializeObject<Dictionary<string, string>>(user.social_media_links)
                        : null,
                    user.registration_date,
                    user.post_count,
                    user.last_activity,
                    user.user_rank,
                    user.signature,
                    PersonalLinks = !string.IsNullOrEmpty(user.personal_links)
                        ? JsonConvert.DeserializeObject<Dictionary<string, string>>(user.personal_links)
                        : null,
                    Hobbies = !string.IsNullOrEmpty(user.hobbies)
                        ? JsonConvert.DeserializeObject<List<string>>(user.hobbies)
                        : null,
                    user.role,
                    user.IsVerified,
                    user.language,
                    user.HashingAlgorithm,
                    user.isBanned
                };

                return Ok(result);
            }
            catch (MySqlException ex)
            {
                return StatusCode(500, new { error = $"Database error: {ex.Message}" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = $"An error occurred: {ex.Message}" });
            }
        }

        // Get user details by ID
        [HttpGet("user/{userId}")]
        public async Task<IActionResult> GetUserById(long userId)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var user = await connection.QueryFirstOrDefaultAsync(
                    @"SELECT id, username, email, bio, status, profile_image_url,
                             location, social_media_links,
                             registration_date, post_count, last_activity,
                             user_rank, signature, personal_links, hobbies,
                             role, IsVerified, language, HashingAlgorithm
                      FROM users WHERE id = @UserId",
                    new { UserId = userId });

                if (user == null)
                    return NotFound(new { error = "User not found" });

                var result = new
                {
                    user.id,
                    user.username,
                    user.email,
                    user.bio,
                    user.status,
                    user.profile_image_url,
                    user.location,
                    SocialMediaLinks = !string.IsNullOrEmpty(user.social_media_links)
                        ? JsonConvert.DeserializeObject<Dictionary<string, string>>(user.social_media_links)
                        : null,
                    user.registration_date,
                    user.post_count,
                    user.last_activity,
                    user.user_rank,
                    user.signature,
                    PersonalLinks = !string.IsNullOrEmpty(user.personal_links)
                        ? JsonConvert.DeserializeObject<Dictionary<string, string>>(user.personal_links)
                        : null,
                    Hobbies = !string.IsNullOrEmpty(user.hobbies)
                        ? JsonConvert.DeserializeObject<List<string>>(user.hobbies)
                        : null,
                    user.role,
                    user.IsVerified,
                    user.language,
                    user.HashingAlgorithm
                };

                return Ok(result);
            }
            catch (MySqlException ex)
            {
                return StatusCode(500, new { error = $"Database error: {ex.Message}" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = $"An error occurred: {ex.Message}" });
            }
        }

        // Update user details
        [HttpPut("user/{userId}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> UpdateUser(long userId, [FromBody] AdminUpdateUserDto updateData)
        {
            if (updateData == null || updateData.UserId != userId)
                return BadRequest("Invalid user data or ID mismatch.");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var existingUser = await connection.QueryFirstOrDefaultAsync<User>(
                    "SELECT * FROM users WHERE id = @UserId",
                    new { UserId = userId });

                if (existingUser == null)
                    return NotFound("User not found.");

                var updateFields = new DynamicParameters();
                updateFields.Add("UserId", userId);

                string newPasswordHash = existingUser.Password;
                string newHashingAlgorithm = existingUser.HashingAlgorithm;

                if (!string.IsNullOrEmpty(updateData.Password))
                {
                    newHashingAlgorithm = updateData.HashingAlgorithm ?? existingUser.HashingAlgorithm;
                    if (newHashingAlgorithm != "Bcrypt" && newHashingAlgorithm != "Argon2id")
                        return BadRequest("Invalid hashing algorithm. Must be 'Bcrypt' or 'Argon2id'.");
                    newPasswordHash = newHashingAlgorithm == "Argon2id"
                        ? HashPasswordArgon2(updateData.Password)
                        : HashPasswordBcrypt(updateData.Password);
                }
                else if (!string.IsNullOrEmpty(updateData.HashingAlgorithm) && updateData.HashingAlgorithm != existingUser.HashingAlgorithm)
                {
                    return BadRequest("Password must be provided to change the hashing algorithm.");
                }

                updateFields.Add("Username", updateData.Username ?? existingUser.Username);
                updateFields.Add("Email", updateData.Email ?? existingUser.Email);
                updateFields.Add("Password", newPasswordHash);
                updateFields.Add("Role", updateData.Role ?? existingUser.Role);
                updateFields.Add("IsVerified", updateData.IsVerified ?? existingUser.IsVerified);
                updateFields.Add("IsBanned", updateData.IsBanned ?? existingUser.IsBanned);
                updateFields.Add("Bio", updateData.Bio);
                updateFields.Add("Status", updateData.Status);
                updateFields.Add("ProfileImageUrl", updateData.ProfileImageUrl);
                updateFields.Add("Location", updateData.Location);
                updateFields.Add("SocialMediaLinks", updateData.SocialMediaLinks != null
                    ? JsonConvert.SerializeObject(updateData.SocialMediaLinks)
                    : existingUser.SocialMediaLinks);
                updateFields.Add("UserRank", updateData.UserRank);
                updateFields.Add("Signature", updateData.Signature);
                updateFields.Add("PersonalLinks", updateData.PersonalLinks != null
                    ? JsonConvert.SerializeObject(updateData.PersonalLinks)
                    : existingUser.PersonalLinks);
                updateFields.Add("Hobbies", updateData.Hobbies != null
                    ? JsonConvert.SerializeObject(updateData.Hobbies)
                    : existingUser.Hobbies);
                updateFields.Add("Language", updateData.Language ?? existingUser.Language);
                updateFields.Add("HashingAlgorithm", newHashingAlgorithm);

                var sql = @"UPDATE users SET 
                    username = @Username,
                    email = @Email,
                    password = @Password,
                    role = @Role,
                    IsVerified = @IsVerified,
                    isBanned = @IsBanned,
                    bio = @Bio,
                    status = @Status,
                    profile_image_url = @ProfileImageUrl,
                    location = @Location,
                    social_media_links = @SocialMediaLinks,
                    user_rank = @UserRank,
                    signature = @Signature,
                    personal_links = @PersonalLinks,
                    hobbies = @Hobbies,
                    language = @Language,
                    HashingAlgorithm = @HashingAlgorithm
                    WHERE id = @UserId";

                var rowsAffected = await connection.ExecuteAsync(sql, updateFields);

                return rowsAffected > 0
                    ? Ok(new { message = "User updated successfully!" })
                    : NotFound("User not found.");
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

        [HttpPost("user/{userId}/ban")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> BanUser(long userId)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var existingUser = await connection.QueryFirstOrDefaultAsync<User>(
                    "SELECT * FROM users WHERE id = @UserId",
                    new { UserId = userId });

                if (existingUser == null)
                    return NotFound("User not found.");

                var rowsAffected = await connection.ExecuteAsync(
                    "UPDATE users SET isBanned = 1 WHERE id = @UserId",
                    new { UserId = userId });

                if (rowsAffected == 0)
                    return NotFound("User not found.");

                // E-mail értesítés küldése
                var emailSubject = "Account Banned Notification";
                var emailBody = $@"Dear {existingUser.Username},

We regret to inform you that your account on The Car Magazine has been banned by an administrator.
If you believe this action was taken in error, please contact our support team for further assistance.

Kind regards,
The Car Magazine Support Team";

                await _emailService.SendEmailAsync(existingUser.Email, emailSubject, emailBody);

                return Ok(new { message = "User banned successfully!" });
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

        // Endpoint to handle content reporting
        [HttpPost("report")]
        [Authorize]
        public async Task<IActionResult> ReportContent([FromBody] ReportContentDto reportDto)
        {
            if (reportDto == null || string.IsNullOrEmpty(reportDto.ContentType) || reportDto.ContentId <= 0)
                return BadRequest(new { error = "Invalid report data: ContentType and ContentId must be valid" });

            if (reportDto.ContentType != "post" && reportDto.ContentType != "subtopic")
                return BadRequest(new { error = "Invalid content type" });

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                // Kinyerjük a bejelentkezett felhasználó userId-jét a tokenből
                var tokenUserId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
                if (string.IsNullOrEmpty(tokenUserId))
                    return Unauthorized(new { error = "Invalid user authentication" });

                int userId = int.Parse(tokenUserId);

                // Ellenőrizzük, hogy a felhasználó létezik-e
                var username = await connection.QuerySingleOrDefaultAsync<string>(
                    "SELECT username FROM users WHERE id = @UserId",
                    new { UserId = userId });

                if (username == null)
                    return BadRequest(new { error = $"User with ID {userId} not found" });

                // Ellenőrizzük, hogy a tartalom létezik-e
                var table = reportDto.ContentType == "post" ? "posts" : "subtopics";
                var contentExists = await connection.ExecuteScalarAsync<int>(
                    $"SELECT COUNT(*) FROM {table} WHERE id = @ContentId",
                    new { reportDto.ContentId });

                if (contentExists == 0)
                    return NotFound(new { error = $"{reportDto.ContentType} with ID {reportDto.ContentId} not found" });

                // Ellenőrizzük, hogy a felhasználó már jelentette-e ezt a tartalmat
                var alreadyReported = await connection.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM reported_content WHERE content_type = @ContentType AND content_id = @ContentId AND user_id = @UserId",
                    new { reportDto.ContentType, reportDto.ContentId, UserId = userId });

                if (alreadyReported > 0)
                    return BadRequest(new { error = "You have already reported this content" });

                var query = @"
            INSERT INTO reported_content (content_type, content_id, user_id, username, reason)
            VALUES (@ContentType, @ContentId, @UserId, @Username, @Reason)";

                var rowsAffected = await connection.ExecuteAsync(query, new
                {
                    reportDto.ContentType,
                    reportDto.ContentId,
                    UserId = userId,
                    Username = username,
                    reportDto.Reason
                });

                return rowsAffected > 0
                    ? Ok(new { message = "Content reported successfully" })
                    : BadRequest(new { error = "Failed to report content" });
            }
            catch (MySqlException ex)
            {
                return StatusCode(500, new { error = $"Database error: {ex.Message}" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = $"An error occurred: {ex.Message}" });
            }
        }

        // Endpoint to get reported content
        [HttpGet("reported-content")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> GetReportedContent([FromQuery] int page = 1, [FromQuery] int perPage = 5)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var offset = (page - 1) * perPage;
                var query = @"
            SELECT 
                rc.id,
                rc.content_type AS type,
                rc.content_id AS contentId,
                rc.user_id AS userId,
                u.username AS reportedBy,
                rc.reason,
                rc.reported_at AS reportedAt,
                CASE 
                    WHEN rc.content_type = 'post' THEN p.content
                    WHEN rc.content_type = 'subtopic' THEN s.title
                    ELSE 'Deleted'
                END AS title,
                CASE 
                    WHEN rc.content_type = 'post' THEN p.subtopic_id
                    WHEN rc.content_type = 'subtopic' THEN s.id
                    ELSE NULL
                END AS subtopicId
            FROM reported_content rc
            LEFT JOIN posts p ON rc.content_type = 'post' AND rc.content_id = p.id
            LEFT JOIN subtopics s ON rc.content_type = 'subtopic' AND rc.content_id = s.id
            LEFT JOIN users u ON rc.user_id = u.id
            WHERE p.id IS NOT NULL OR s.id IS NOT NULL
            ORDER BY rc.reported_at DESC
            LIMIT @PerPage OFFSET @Offset";

                var reportedContent = await connection.QueryAsync<ReportedContentDto>(query, new { PerPage = perPage, Offset = offset });

                return Ok(reportedContent);
            }
            catch (MySqlException ex)
            {
                return StatusCode(500, new { error = $"Database error: {ex.Message}" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = $"An error occurred: {ex.Message}" });
            }
        }

        // Endpoint to delete content
        [HttpDelete("reported/{contentId}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> DeleteReportedContent(long contentId, [FromQuery] string contentType)
        {
            if (contentType != "post" && contentType != "subtopic")
                return BadRequest(new { error = "Invalid content type" });

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var reportedContent = await connection.QueryFirstOrDefaultAsync(
                    "SELECT content_type, content_id FROM reported_content WHERE content_id = @ContentId AND content_type = @ContentType",
                    new { ContentId = contentId, ContentType = contentType });

                if (reportedContent == null)
                    return NotFound(new { error = $"Reported {contentType} not found" });

                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    int rowsAffected;
                    if (contentType == "post")
                    {
                        await connection.ExecuteAsync(
                            "DELETE FROM posts WHERE parent_post_id = @ContentId",
                            new { ContentId = contentId },
                            transaction);

                        rowsAffected = await connection.ExecuteAsync(
                            "DELETE FROM posts WHERE id = @ContentId",
                            new { ContentId = contentId },
                            transaction);
                    }
                    else // subtopic
                    {
                        // Először töröljük a subtopichoz tartozó posztokat
                        await connection.ExecuteAsync(
                            "DELETE FROM posts WHERE subtopic_id = @ContentId",
                            new { ContentId = contentId },
                            transaction);

                        rowsAffected = await connection.ExecuteAsync(
                            "DELETE FROM subtopics WHERE id = @ContentId",
                            new { ContentId = contentId },
                            transaction);
                    }

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        return NotFound(new { error = $"{contentType} not found" });
                    }

                    await connection.ExecuteAsync(
                        "DELETE FROM reported_content WHERE content_type = @ContentType AND content_id = @ContentId",
                        new { ContentType = contentType, ContentId = contentId },
                        transaction);

                    await transaction.CommitAsync();

                    return Ok(new { message = $"{contentType} and associated reports deleted successfully" });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    Console.WriteLine($"Transaction error: {ex.Message}, StackTrace: {ex.StackTrace}");
                    throw;
                }
            }
            catch (MySqlException ex)
            {
                return StatusCode(500, new { error = $"Database error: {ex.Message}" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = $"An error occurred: {ex.Message}" });
            }
        }

        [HttpPost("reported/{contentId}/accept")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> AcceptReport(long contentId, [FromQuery] string contentType)
        {
            if (string.IsNullOrEmpty(contentType) || (contentType != "post" && contentType != "subtopic"))
                return BadRequest(new { error = "Invalid or missing content type" });

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var rowsAffected = await connection.ExecuteAsync(
                    "DELETE FROM reported_content WHERE content_type = @ContentType AND content_id = @ContentId",
                    new { ContentType = contentType, ContentId = contentId });

                if (rowsAffected == 0)
                    return NotFound(new { error = $"Reported {contentType} not found" });

                return Ok(new { message = "Report accepted successfully" });
            }
            catch (MySqlException ex)
            {
                return StatusCode(500, new { error = $"Database error: {ex.Message}" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = $"An error occurred: {ex.Message}" });
            }
        }

        // Support ticketek lekérdezése
        [HttpGet("support-tickets")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> GetSupportTickets()
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                var tickets = await connection.QueryAsync(
                    @"SELECT id, user_id, username, email, subject, message, submitted_at, status
                      FROM support_messages
                      WHERE status IN ('new', 'in_progress')
                      ORDER BY submitted_at DESC"
                );

                return Ok(tickets);
            }
            catch (MySqlException ex)
            {
                Console.WriteLine($"MySQL error: {ex.Message}, ErrorCode: {ex.Number}");
                return StatusCode(500, $"Database error: {ex.Message}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"General error: {ex.Message}, StackTrace: {ex.StackTrace}");
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        // Support ticket állapotának frissítése
        [HttpPut("support-ticket/{ticketId}/status")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> UpdateTicketStatus(int ticketId, [FromBody] UpdateTicketStatusDto statusDto)
        {
            if (statusDto == null || string.IsNullOrWhiteSpace(statusDto.Status))
                return BadRequest("Status is required.");

            if (!new[] { "new", "in_progress", "resolved" }.Contains(statusDto.Status))
                return BadRequest("Invalid status value.");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    int rowsAffected = await connection.ExecuteAsync(
                        @"UPDATE support_messages 
                          SET status = @Status
                          WHERE id = @TicketId",
                        new { TicketId = ticketId, Status = statusDto.Status },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        return NotFound("Ticket not found.");
                    }

                    await transaction.CommitAsync();
                    return Ok(new { message = "Ticket status updated successfully." });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    Console.WriteLine($"Transaction error: {ex.Message}, StackTrace: {ex.StackTrace}");
                    return StatusCode(500, $"Transaction error: {ex.Message}");
                }
            }
            catch (MySqlException ex)
            {
                Console.WriteLine($"MySQL error: {ex.Message}, ErrorCode: {ex.Number}");
                return StatusCode(500, $"Database error: {ex.Message}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"General error: {ex.Message}, StackTrace: {ex.StackTrace}");
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpDelete("support-ticket/{ticketId}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> DeleteSupportTicket(int ticketId)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    // Ticket létezésének ellenőrzése
                    var ticket = await connection.QueryFirstOrDefaultAsync(
                        @"SELECT id FROM support_messages WHERE id = @TicketId",
                        new { TicketId = ticketId },
                        transaction);

                    if (ticket == null)
                    {
                        await transaction.RollbackAsync();
                        return NotFound("Ticket not found.");
                    }

                    // Ticket törlése
                    int rowsAffected = await connection.ExecuteAsync(
                        @"DELETE FROM support_messages WHERE id = @TicketId",
                        new { TicketId = ticketId },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        return StatusCode(500, "Failed to delete ticket.");
                    }

                    await transaction.CommitAsync();
                    return Ok(new { message = "Ticket deleted successfully." });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    Console.WriteLine($"Transaction error: {ex.Message}, StackTrace: {ex.StackTrace}");
                    return StatusCode(500, $"Transaction error: {ex.Message}");
                }
            }
            catch (MySqlException ex)
            {
                Console.WriteLine($"MySQL error: {ex.Message}, ErrorCode: {ex.Number}");
                return StatusCode(500, $"Database error: {ex.Message}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"General error: {ex.Message}, StackTrace: {ex.StackTrace}");
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        // Válasz e-mail küldése
        [HttpPost("support-ticket/{ticketId}/respond")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> SendResponseEmail(int ticketId, [FromBody] RespondTicketDto respondDto)
        {
            if (respondDto == null || string.IsNullOrWhiteSpace(respondDto.UserEmail) ||
                string.IsNullOrWhiteSpace(respondDto.ResponseText))
                return BadRequest("User email and response text are required.");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    // Ticket létezésének ellenőrzése
                    var ticket = await connection.QueryFirstOrDefaultAsync(
                        @"SELECT id, subject, email FROM support_messages WHERE id = @TicketId",
                        new { TicketId = ticketId },
                        transaction);

                    if (ticket == null)
                    {
                        await transaction.RollbackAsync();
                        return NotFound("Ticket not found.");
                    }

                    // E-mail sablon
                    var emailSubject = $"Response to Your Support Ticket: {respondDto.Subject}";
                    var emailBody = $@"
Dear User,

We acknowledge the receipt of your support ticket regarding ""{respondDto.Subject}"". Please find our response below:

{respondDto.ResponseText}

If you require any further clarification or assistance, you are welcome to respond to this message.

Kind regards,
The Car Magazine Support Team
";

                    // E-mail küldése
                    await _emailService.SendEmailAsync(respondDto.UserEmail, emailSubject, emailBody);

                    // Ticket állapotának frissítése in_progress-re
                    await connection.ExecuteAsync(
                        @"UPDATE support_messages 
                          SET status = 'in_progress'
                          WHERE id = @TicketId",
                        new { TicketId = ticketId },
                        transaction);

                    await transaction.CommitAsync();
                    return Ok(new { message = "Response email sent successfully." });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    Console.WriteLine($"Transaction error: {ex.Message}, StackTrace: {ex.StackTrace}");
                    return StatusCode(500, $"Transaction error: {ex.Message}");
                }
            }
            catch (MySqlException ex)
            {
                Console.WriteLine($"MySQL error: {ex.Message}, ErrorCode: {ex.Number}");
                return StatusCode(500, $"Database error: {ex.Message}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"General error: {ex.Message}, StackTrace: {ex.StackTrace}");
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpPost("support-ticket/{ticketId}/resolve-email")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> ResolveSupportTicket(int ticketId, [FromBody] DeleteTicketDto deleteDto)
        {
            if (deleteDto == null || string.IsNullOrWhiteSpace(deleteDto.UserEmail))
                return BadRequest("User email is required.");

            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    // Ticket létezésének ellenőrzése
                    var ticket = await connection.QueryFirstOrDefaultAsync(
                        @"SELECT id, subject, email FROM support_messages WHERE id = @TicketId",
                        new { TicketId = ticketId },
                        transaction);

                    if (ticket == null)
                    {
                        await transaction.RollbackAsync();
                        return NotFound("Ticket not found.");
                    }

                    // Státusz frissítése resolved-re
                    int rowsAffected = await connection.ExecuteAsync(
                        @"UPDATE support_messages 
                          SET status = 'resolved'
                          WHERE id = @TicketId",
                        new { TicketId = ticketId },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        return StatusCode(500, "Failed to resolve ticket.");
                    }

                    // E-mail sablon
                    var emailSubject = $"The Car Magazine - Support ticket marked as SOLVED.";
                    var emailBody = $@"Dear User,
We would like to inform you that your support ticket titled {deleteDto.Subject} has been marked as SOLVED by an administrator.
Should you have any additional inquiries or require further assistance, please feel free to submit a new support request at your convenience.
Kind regards,
The Car Magazine Support Team
";

                    // E-mail küldése
                    await _emailService.SendEmailAsync(deleteDto.UserEmail, emailSubject, emailBody);

                    await transaction.CommitAsync();
                    return Ok(new { message = "Ticket resolved and notification email sent." });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    Console.WriteLine($"Transaction error: {ex.Message}, StackTrace: {ex.StackTrace}");
                    return StatusCode(500, $"Transaction error: {ex.Message}");
                }
            }
            catch (MySqlException ex)
            {
                Console.WriteLine($"MySQL error: {ex.Message}, ErrorCode: {ex.Number}");
                return StatusCode(500, $"Database error: {ex.Message}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"General error: {ex.Message}, StackTrace: {ex.StackTrace}");
                return StatusCode(500, $"An error occurred: {ex.Message}");
            }
        }

        [HttpDelete("marketplace/{carId}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> DeleteMarketplaceListing(long carId)
        {
            try
            {
                using var connection = new MySqlConnection(_connectionString);
                await connection.OpenAsync();

                using var transaction = await connection.BeginTransactionAsync();

                try
                {
                    // Ellenőrizzük, hogy a bejegyzés létezik-e
                    var existingListing = await connection.QueryFirstOrDefaultAsync(
                        "SELECT id FROM car_listings_new WHERE id = @CarId",
                        new { CarId = carId },
                        transaction);

                    if (existingListing == null)
                    {
                        await transaction.RollbackAsync();
                        return NotFound(new { error = "Listing not found" });
                    }

                    // Törlés a car_listings_new táblából
                    int rowsAffected = await connection.ExecuteAsync(
                        "DELETE FROM car_listings_new WHERE id = @CarId",
                        new { CarId = carId },
                        transaction);

                    if (rowsAffected == 0)
                    {
                        await transaction.RollbackAsync();
                        return StatusCode(500, "Failed to delete listing");
                    }

                    await transaction.CommitAsync();
                    return Ok(new { message = "Listing deleted successfully" });
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    Console.WriteLine($"Transaction error: {ex.Message}, StackTrace: {ex.StackTrace}");
                    throw;
                }
            }
            catch (MySqlException ex)
            {
                return StatusCode(500, new { error = $"Database error: {ex.Message}" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = $"An error occurred: {ex.Message}" });
            }
        }
    }


}