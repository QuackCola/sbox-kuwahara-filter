using Sandbox;

public sealed class NoClip : Component
{
	[Property] public float MoveSpeed { get; set; } = 600.0f;

	Angles eyeAngles;

	protected override void OnStart()
	{
		eyeAngles = Transform.Rotation;
	}

	protected override void OnUpdate()
	{
		eyeAngles.pitch += Input.AnalogLook.pitch * 10.0f;
		eyeAngles.yaw += Input.AnalogLook.yaw * 10.0f;

		Vector3 movement = Input.AnalogMove;

		Transform.Rotation = eyeAngles;

		if ( !movement.IsNearlyZero() )
		{
			Transform.Position += Transform.Rotation * movement.Normal * Time.Delta * MoveSpeed;
		}
	}
}
