using CloudinaryDotNet;
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using MySql.Data.MySqlClient;
using System.Security.Claims; 
using TheCarMagazinAPI.Models;
using TheCarMagazinAPI.DTOs;


[Route("api/magazine")]
[ApiController]
public class MagazineController : ControllerBase
{
    private readonly string _connectionString;
    private readonly Cloudinary _cloudinary;
    private readonly string _uploadPreset;

    public MagazineController(IConfiguration configuration, IOptions<AppSettings> appSettings)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new ArgumentException("Connection string 'DefaultConnection' is missing in appsettings.json");

        var cloudinarySettings = appSettings?.Value?.Cloudinary;
        if (cloudinarySettings == null)
        {
            throw new ArgumentException("Cloudinary settings are missing in appsettings.json");
        }

        if (string.IsNullOrEmpty(cloudinarySettings.CloudName) ||
            string.IsNullOrEmpty(cloudinarySettings.ApiKey) ||
            string.IsNullOrEmpty(cloudinarySettings.ApiSecret) ||
            string.IsNullOrEmpty(cloudinarySettings.UploadPreset))
        {
            throw new ArgumentException("One or more Cloudinary settings (CloudName, ApiKey, ApiSecret, UploadPreset) are empty in appsettings.json");
        }

        _cloudinary = new Cloudinary(new Account(
            cloudinarySettings.CloudName,
            cloudinarySettings.ApiKey,
            cloudinarySettings.ApiSecret));

        _uploadPreset = cloudinarySettings.UploadPreset;
    }

    [HttpGet("articles")]
    public async Task<IActionResult> GetArticles()
    {
        try
        {
            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();
            var articles = await connection.QueryAsync(
                "SELECT id, user_id AS userId, title, description, image_url AS imageUrl, category, placement, created_at AS createdAt, last_updated_at AS lastUpdatedAt " +
                "FROM magazine_articles");
            return Ok(articles);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Failed to fetch articles", details = ex.Message });
        }
    }

    [Authorize]
    [HttpPost("articles")]
    public async Task<IActionResult> CreateArticle([FromBody] CreateArticleDto articleDto)
    {
        try
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdClaim) || !long.TryParse(userIdClaim, out var tokenUserId))
            {
                return Unauthorized(new { error = "Invalid user token" });
            }

            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();
            using var transaction = await connection.BeginTransactionAsync();

            var userRole = await connection.QuerySingleOrDefaultAsync<string>(
                "SELECT role FROM users WHERE id = @UserId",
                new { UserId = tokenUserId },
                transaction);

            if (userRole != "admin")
            {
                await transaction.RollbackAsync();
                return StatusCode(403, new { error = "Only admins can create articles" });
            }

            if (string.IsNullOrEmpty(articleDto.Title))
            {
                await transaction.RollbackAsync();
                return BadRequest(new { error = "Title is required" });
            }

            if (string.IsNullOrEmpty(articleDto.Description))
            {
                await transaction.RollbackAsync();
                return BadRequest(new { error = "Description is required" });
            }

            if (string.IsNullOrEmpty(articleDto.ImageUrl))
            {
                await transaction.RollbackAsync();
                return BadRequest(new { error = "Image URL is required" });
            }

            // Validate placement
            var validPlacements = new[] { "featured", "grid", "list" };
            var placement = string.IsNullOrEmpty(articleDto.Placement) ? "list" : articleDto.Placement.ToLower();
            if (!validPlacements.Contains(placement))
            {
                await transaction.RollbackAsync();
                return BadRequest(new { error = "Invalid placement value. Must be 'featured', 'grid', or 'list'." });
            }

            // Handle placement constraints
            if (placement == "featured")
            {
                // Move existing featured article to list
                await connection.ExecuteAsync(
                    "UPDATE magazine_articles SET placement = 'list' WHERE placement = 'featured'",
                    transaction: transaction);
            }
            else if (placement == "grid")
            {
                // Check if there are already 5 grid articles
                var gridCount = await connection.ExecuteScalarAsync<int>(
                    "SELECT COUNT(*) FROM magazine_articles WHERE placement = 'grid'",
                    transaction: transaction);
                if (gridCount >= 5)
                {
                    // Move the oldest grid article to list
                    await connection.ExecuteAsync(
                        "UPDATE magazine_articles SET placement = 'list' " +
                        "WHERE placement = 'grid' AND created_at = (SELECT MIN(created_at) FROM magazine_articles WHERE placement = 'grid')",
                        transaction: transaction);
                }
            }

            // Insert new article
            var query = @"INSERT INTO magazine_articles (user_id, title, description, image_url, category, placement, created_at, last_updated_at)
                         VALUES (@UserId, @Title, @Description, @ImageUrl, @Category, @Placement, @CreatedAt, @LastUpdatedAt);
                         SELECT LAST_INSERT_ID();";
            var articleId = await connection.ExecuteScalarAsync<long>(query, new
            {
                UserId = tokenUserId, // Use tokenUserId, ignore articleDto.UserId
                articleDto.Title,
                articleDto.Description,
                articleDto.ImageUrl,
                articleDto.Category,
                Placement = placement,
                CreatedAt = DateTime.UtcNow,
                LastUpdatedAt = DateTime.UtcNow
            }, transaction);

            await transaction.CommitAsync();

            return CreatedAtAction(nameof(GetArticles), new { id = articleId }, new { id = articleId });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = "Failed to create article", details = ex.Message });
        }
    }
}

