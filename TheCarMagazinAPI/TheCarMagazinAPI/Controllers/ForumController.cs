using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;
using System.Security.Claims;

[Route("api/forum")]
[ApiController]
public class ForumController : ControllerBase
{
    private readonly string _connectionString;

    public ForumController(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection");
    }

    [HttpGet("topics")]
    public async Task<IActionResult> GetTopics()
    {
        using var connection = new MySqlConnection(_connectionString);
        var topics = await connection.QueryAsync(
            "SELECT id, topic, description, created_at AS createdAt, last_updated_at AS lastUpdatedAt, username, category " +
            "FROM topics");
        return Ok(topics);
    }

    [HttpGet("topics/{topicId}")]
    public async Task<IActionResult> GetTopicById(long topicId)
    {
        using var connection = new MySqlConnection(_connectionString);
        var topic = await connection.QueryFirstOrDefaultAsync(
            "SELECT id, topic, description, created_at AS createdAt, last_updated_at AS lastUpdatedAt, username, category " +
            "FROM topics WHERE id = @TopicId",
            new { TopicId = topicId });

        if (topic == null)
        {
            return NotFound($"Topic with ID {topicId} not found.");
        }
        return Ok(topic);
    }

    [HttpGet("topics/{topicId}/subtopics")]
    public async Task<IActionResult> GetSubtopics(long topicId)
    {
        using var connection = new MySqlConnection(_connectionString);
        var topicExists = await connection.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM topics WHERE id = @TopicId",
            new { TopicId = topicId });
        if (topicExists == 0)
        {
            return NotFound($"Topic with ID {topicId} not found.");
        }

        var subtopics = await connection.QueryAsync(
            "SELECT id, title, description, created_at AS createdAt, username " +
            "FROM subtopics WHERE topic_id = @TopicId",
            new { TopicId = topicId });
        return Ok(subtopics);
    }

    [HttpPost("topics/{topicId}/subtopics")]
    [Authorize]
    public async Task<IActionResult> CreateSubtopic(long topicId, [FromBody] SubtopicDto subtopicDto)
    {
        using var connection = new MySqlConnection(_connectionString);
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var username = User.FindFirst(ClaimTypes.Name)?.Value ?? "Unknown";

        if (string.IsNullOrWhiteSpace(subtopicDto.Title))
        {
            return BadRequest("Subtopic title is required.");
        }

        // Ellenőrizd, hogy a topic létezik-e
        var topicExists = await connection.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM topics WHERE id = @TopicId",
            new { TopicId = topicId });
        if (topicExists == 0)
        {
            return NotFound($"Topic with ID {topicId} not found.");
        }

        long userId;
        try
        {
            userId = long.Parse(userIdClaim);
        }
        catch
        {
            return BadRequest("Invalid user ID in token.");
        }

        try
        {
            var subtopicId = await connection.ExecuteScalarAsync<long>(
                "INSERT INTO subtopics (topic_id, title, description, user_id, username, created_at) " +
                "VALUES (@TopicId, @Title, @Description, @UserId, @Username, NOW()); SELECT LAST_INSERT_ID();",
                new
                {
                    TopicId = topicId,
                    subtopicDto.Title,
                    subtopicDto.Description,
                    UserId = userId,
                    Username = username
                });

            await connection.ExecuteAsync(
                "UPDATE topics SET last_updated_at = NOW() WHERE id = @TopicId",
                new { TopicId = topicId });

            return Created($"/api/forum/topics/{topicId}/subtopics/{subtopicId}", new { id = subtopicId });
        }
        catch (Exception ex)
        {
            return StatusCode(500, $"Error creating subtopic: {ex.Message}");
        }
    }

    [HttpGet("subtopics/{subtopicId}/posts")]
    public async Task<IActionResult> GetPosts(long subtopicId)
    {
        using var connection = new MySqlConnection(_connectionString);
        var subtopicExists = await connection.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM subtopics WHERE id = @SubtopicId",
            new { SubtopicId = subtopicId });
        if (subtopicExists == 0)
        {
            return NotFound($"Subtopic with ID {subtopicId} not found.");
        }

        var posts = await connection.QueryAsync(
            "SELECT p.id, p.content, p.created_at AS createdAt, p.user_id AS userId, p.parent_post_id AS parentPostId, u.username " +
            "FROM posts p LEFT JOIN users u ON p.user_id = u.id " +
            "WHERE p.subtopic_id = @SubtopicId",
            new { SubtopicId = subtopicId });
        return Ok(posts);
    }

    [HttpPost("topics/{subtopicId}/posts")]
    [Authorize]
    public async Task<IActionResult> CreatePost(long subtopicId, [FromBody] PostDto postDto)
    {
        using var connection = new MySqlConnection(_connectionString);
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var username = User.FindFirst(ClaimTypes.Name)?.Value ?? "Unknown";

        if (string.IsNullOrWhiteSpace(postDto.Content))
        {
            return BadRequest("Post content is required.");
        }

        // Ellenőrizd, hogy a subtopic létezik-e
        var subtopicExists = await connection.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM subtopics WHERE id = @SubtopicId",
            new { SubtopicId = subtopicId });
        if (subtopicExists == 0)
        {
            return NotFound($"Subtopic with ID {subtopicId} not found.");
        }

        long userId;
        try
        {
            userId = long.Parse(userIdClaim);
        }
        catch
        {
            return BadRequest("Invalid user ID in token.");
        }

        try
        {
            var postId = await connection.ExecuteScalarAsync<long>(
                "INSERT INTO posts (subtopic_id, content, user_id, created_at, parent_post_id) " +
                "VALUES (@SubtopicId, @Content, @UserId, NOW(), @ParentPostId); SELECT LAST_INSERT_ID();",
                new { SubtopicId = subtopicId, postDto.Content, UserId = userId, postDto.ParentPostId });

            return Created($"/api/forum/topics/{subtopicId}/posts/{postId}", new { id = postId, username });
        }
        catch (Exception ex)
        {
            return StatusCode(500, $"Error creating post: {ex.Message}");
        }
    }
}

public class SubtopicDto
{
    public string Title { get; set; }
    public string Description { get; set; }
}

public class PostDto
{
    public string Content { get; set; }
    public long? ParentPostId { get; set; }
}