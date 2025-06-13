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
            "SELECT id, topic, description, created_at AS createdAt, last_updated_at AS lastUpdatedAt, category " +
            "FROM topics");
        return Ok(topics);
    }

    [HttpGet("topics/{topicId}")]
    public async Task<IActionResult> GetTopicById(long topicId)
    {
        try
        {
            using var connection = new MySqlConnection(_connectionString);
            var topic = await connection.QueryFirstOrDefaultAsync(
                @"SELECT t.id, t.topic, t.description, t.created_at AS createdAt, 
                     t.last_updated_at AS lastUpdatedAt, t.category, u.username
              FROM topics t
              LEFT JOIN users u ON t.user_id = u.id
              WHERE t.id = @TopicId",
                new { TopicId = topicId });

            if (topic == null)
            {
                return NotFound($"Topic with ID {topicId} not found.");
            }
            return Ok(topic);
        }
        catch (MySqlException ex)
        {
            return StatusCode(500, $"Database error: {ex.Message}");
        }
    }

    [HttpGet("subtopics/created/{userId}")]
    [Authorize]
    public async Task<IActionResult> GetCreatedSubtopics(long userId)
    {
        try
        {
            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();

            var subtopics = await connection.QueryAsync(
                @"SELECT id, topic_id AS topicId, title, created_at AS createdAt, description, username
              FROM subtopics 
              WHERE user_id = @UserId 
              ORDER BY created_at DESC",
                new { UserId = userId });

            return Ok(subtopics);
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
            "SELECT id, title, description, created_at AS createdAt, user_id AS userId, username " +
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
        long? userId = null;
        try
        {
            userId = User.Identity.IsAuthenticated
                ? long.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value)
                : null;
        }
        catch
        {
            // Ignore invalid user ID for unauthenticated users
        }

        using var connection = new MySqlConnection(_connectionString);
        var subtopicExists = await connection.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM subtopics WHERE id = @SubtopicId",
            new { SubtopicId = subtopicId });
        if (subtopicExists == 0)
        {
            return NotFound($"Subtopic with ID {subtopicId} not found.");
        }

        var posts = await connection.QueryAsync(
            @"SELECT p.id, p.content, p.created_at AS createdAt, p.user_id AS userId, 
                 p.parent_post_id AS parentPostId, u.username, 
                 p.upvote_count AS upvoteCount, p.downvote_count AS downvoteCount,
                 pv.vote_type AS userVote
          FROM posts p 
          LEFT JOIN users u ON p.user_id = u.id 
          LEFT JOIN post_votes pv ON p.id = pv.post_id AND pv.user_id = @UserId
          WHERE p.subtopic_id = @SubtopicId",
            new { SubtopicId = subtopicId, UserId = userId });
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
    [HttpGet("subtopics/{subtopicId}")]
    [AllowAnonymous] // Adjust authorization as needed
    public async Task<IActionResult> GetSubtopic(long subtopicId)
    {
        try
        {
            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();

            var query = @"
            SELECT id, title, description, created_at AS createdAt, user_id, username
            FROM subtopics
            WHERE id = @SubtopicId";

            var subtopic = await connection.QueryFirstOrDefaultAsync(query, new { SubtopicId = subtopicId });

            if (subtopic == null)
                return NotFound(new { error = "Subtopic not found" });

            return Ok(subtopic);
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



    [HttpGet("posts/{postId}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetPost(long postId)
    {
        try
        {
            using var connection = new MySqlConnection(_connectionString);
            await connection.OpenAsync();

            var query = @"
            SELECT p.id, p.content, p.created_at AS createdAt, p.user_id AS userId, 
                   p.parent_post_id AS parentPostId, u.username, p.subtopic_id AS subtopicId
            FROM posts p 
            LEFT JOIN users u ON p.user_id = u.id 
            WHERE p.id = @PostId";

            var post = await connection.QueryFirstOrDefaultAsync(query, new { PostId = postId });

            if (post == null)
                return NotFound(new { error = "Post not found" });

            return Ok(post);
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
    [HttpPost("posts/{postId}/vote")]
    [Authorize]
    public async Task<IActionResult> VotePost(long postId, [FromBody] VoteDto voteDto)
    {
        if (voteDto.VoteType != "upvote" && voteDto.VoteType != "downvote")
        {
            return BadRequest("Invalid vote type. Use 'upvote' or 'downvote'.");
        }

        long userId;
        try
        {
            userId = long.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);
        }
        catch
        {
            return BadRequest("Invalid user ID in token.");
        }

        using var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync();
        using var transaction = await connection.BeginTransactionAsync();

        try
        {
            // Check if post exists
            var postExists = await connection.ExecuteScalarAsync<int>(
                "SELECT COUNT(*) FROM posts WHERE id = @PostId",
                new { PostId = postId },
                transaction);
            if (postExists == 0)
            {
                return NotFound($"Post with ID {postId} not found.");
            }

            // Check if user already voted
            var existingVote = await connection.QueryFirstOrDefaultAsync(
                "SELECT vote_type FROM post_votes WHERE user_id = @UserId AND post_id = @PostId",
                new { UserId = userId, PostId = postId },
                transaction);

            if (existingVote == null)
            {
                // New vote
                await connection.ExecuteAsync(
                    "INSERT INTO post_votes (user_id, post_id, vote_type) VALUES (@UserId, @PostId, @VoteType)",
                    new { UserId = userId, PostId = postId, VoteType = voteDto.VoteType },
                    transaction);

                // Update vote count
                var updateQuery = voteDto.VoteType == "upvote"
                    ? "UPDATE posts SET upvote_count = upvote_count + 1 WHERE id = @PostId"
                    : "UPDATE posts SET downvote_count = downvote_count + 1 WHERE id = @PostId";
                await connection.ExecuteAsync(updateQuery, new { PostId = postId }, transaction);
            }
            else if (existingVote.vote_type != voteDto.VoteType)
            {
                // Update existing vote
                await connection.ExecuteAsync(
                    "UPDATE post_votes SET vote_type = @VoteType WHERE user_id = @UserId AND post_id = @PostId",
                    new { UserId = userId, PostId = postId, VoteType = voteDto.VoteType },
                    transaction);

                // Adjust vote counts
                var decrementQuery = existingVote.vote_type == "upvote"
                    ? "UPDATE posts SET upvote_count = upvote_count - 1 WHERE id = @PostId"
                    : "UPDATE posts SET downvote_count = downvote_count - 1 WHERE id = @PostId";
                var incrementQuery = voteDto.VoteType == "upvote"
                    ? "UPDATE posts SET upvote_count = upvote_count + 1 WHERE id = @PostId"
                    : "UPDATE posts SET downvote_count = downvote_count + 1 WHERE id = @PostId";
                await connection.ExecuteAsync(decrementQuery, new { PostId = postId }, transaction);
                await connection.ExecuteAsync(incrementQuery, new { PostId = postId }, transaction);
            }
            else
            {
                return BadRequest("User has already voted with the same vote type.");
            }

            await transaction.CommitAsync();
            return Ok();
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync();
            return StatusCode(500, $"Error processing vote: {ex.Message}");
        }
    }

    [HttpDelete("posts/{postId}/vote")]
    [Authorize]
    public async Task<IActionResult> RemoveVote(long postId)
    {
        long userId;
        try
        {
            userId = long.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value);
        }
        catch
        {
            return BadRequest("Invalid user ID in token.");
        }

        using var connection = new MySqlConnection(_connectionString);
        await connection.OpenAsync();
        using var transaction = await connection.BeginTransactionAsync();

        try
        {
            // Check if vote exists
            var vote = await connection.QueryFirstOrDefaultAsync(
                "SELECT vote_type FROM post_votes WHERE user_id = @UserId AND post_id = @PostId",
                new { UserId = userId, PostId = postId },
                transaction);

            if (vote == null)
            {
                return NotFound("No vote found for this post by the user.");
            }

            // Delete vote
            await connection.ExecuteAsync(
                "DELETE FROM post_votes WHERE user_id = @UserId AND post_id = @PostId",
                new { UserId = userId, PostId = postId },
                transaction);

            // Update vote count
            var updateQuery = vote.vote_type == "upvote"
                ? "UPDATE posts SET upvote_count = upvote_count - 1 WHERE id = @PostId"
                : "UPDATE posts SET downvote_count = downvote_count - 1 WHERE id = @PostId";
            await connection.ExecuteAsync(updateQuery, new { PostId = postId }, transaction);

            await transaction.CommitAsync();
            return Ok();
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync();
            return StatusCode(500, $"Error removing vote: {ex.Message}");
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

public class VoteDto
{
    public string VoteType { get; set; } // "upvote" or "downvote"
}