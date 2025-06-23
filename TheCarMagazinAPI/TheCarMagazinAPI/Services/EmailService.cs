using System.Net;
using System.Net.Mail;

namespace TheCarMagazinAPI.Services
{
    public class EmailService : IEmailService
    {
        private readonly string _smtpServer;
        private readonly int _smtpPort;
        private readonly string _senderEmail;
        private readonly string _senderPassword;
        private readonly string _senderName;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
        {
            var emailSettings = configuration.GetSection("EmailSettings");
            _smtpServer = emailSettings["SmtpServer"] ?? throw new ArgumentNullException(nameof(emailSettings), "SmtpServer is not configured.");
            _smtpPort = int.TryParse(emailSettings["SmtpPort"], out var port) ? port : throw new ArgumentNullException(nameof(emailSettings), "SmtpPort is not configured or invalid.");
            _senderEmail = emailSettings["SenderEmail"] ?? throw new ArgumentNullException(nameof(emailSettings), "SenderEmail is not configured.");
            _senderPassword = emailSettings["SenderPassword"] ?? throw new ArgumentNullException(nameof(emailSettings), "SenderPassword is not configured.");
            _senderName = emailSettings["SenderName"] ?? "The Car Magazine Verify";
            _logger = logger;
        }

        public async Task SendEmailAsync(string toEmail, string subject, string body)
        {
            if (string.IsNullOrWhiteSpace(toEmail))
                throw new ArgumentException("Recipient email cannot be empty.", nameof(toEmail));
            if (string.IsNullOrWhiteSpace(subject))
                throw new ArgumentException("Email subject cannot be empty.", nameof(subject));
            if (string.IsNullOrWhiteSpace(body))
                throw new ArgumentException("Email body cannot be empty.", nameof(body));

            try
            {
                using var smtpClient = new SmtpClient(_smtpServer)
                {
                    Port = _smtpPort,
                    Credentials = new NetworkCredential(_senderEmail, _senderPassword),
                    EnableSsl = true,
                    Timeout = 5000,
                };

                var mailMessage = new MailMessage
                {
                    From = new MailAddress(_senderEmail, _senderName),
                    Subject = subject,
                    Body = body,
                    IsBodyHtml = false,
                };
                mailMessage.To.Add(toEmail);

                await smtpClient.SendMailAsync(mailMessage);
                _logger.LogInformation($"Email sent successfully to {toEmail}. Subject: {subject}");
            }
            catch (SmtpException ex)
            {
                _logger.LogError(ex, $"Failed to send email to {toEmail}. Subject: {subject}");
                throw new InvalidOperationException($"Failed to send email: {ex.Message}", ex);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"An error occurred while sending email to {toEmail}. Subject: {subject}");
                throw new InvalidOperationException($"An error occurred while sending email: {ex.Message}", ex);
            }
        }
    }
}