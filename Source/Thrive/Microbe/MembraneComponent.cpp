// Copyright (C) 2013-2017  Revolutionary Games

#include "Thrive.h"
#include "MembraneComponent.h"

#include <cmath>


UMembraneComponent::UMembraneComponent() : Super(){
    
}

// ------------------------------------ //
void UMembraneComponent::BeginPlay(){

    Super::BeginPlay();

}

void UMembraneComponent::CreateMembraneMesh(URuntimeMeshComponent* GeometryReceiver){

    if(OrganelleContainerComponent){

        // TODO: apply organelle data
        
    }

    // Dummy data
    for(int x = -4; x < 5; ++x){

        for(int y = -4; y < 5; ++y){

            OrganellePositions.Emplace(FVector2D(x, y));
        }
    }

    // Generate mesh data //

    MeshPoints.Empty();

    // This initializes the 2D points and then starts moving them towards organelles
    DoMembraneIterativeShrink();

    // One more iteration
    DrawMembrane();

    // Setup 3D points
    MakePrism();
    CalcUVCircle();


    // Create renderable from the mesh data //

    TArray<FVector> Vertices;
    TArray<FVector> Normals;
    TArray<FRuntimeMeshTangent> Tangents;
    TArray<FVector2D> TextureCoordinates;
    TArray<int32> Triangles;

    URuntimeMeshLibrary::CreateBoxMesh(FVector(50, 50, 50), Vertices, Triangles, Normals,
        TextureCoordinates, Tangents);

    // Create the mesh section specifying collision
    GeometryReceiver->CreateMeshSection(0, Vertices, Triangles, Normals, TextureCoordinates,
        TArray<FColor>(), Tangents, true, EUpdateFrequency::Infrequent);

    GeometryReceiver->AddCollisionConvexMesh(Vertices);

    if(GeometryReceiver->GetBodyInstance())
    {
        GeometryReceiver->GetBodyInstance()->bLockXRotation = true;
        GeometryReceiver->GetBodyInstance()->bLockYRotation = true;

        GeometryReceiver->GetBodyInstance()->SetDOFLock(EDOFMode::XYPlane);
    }
}

// ------------------------------------ //
void UMembraneComponent::DoMembraneIterativeShrink(){

    // Reset dimensions before calculating the new required dimensions
    CellDimensions = 10;

    for (FVector2D pos : OrganellePositions) {
        if (std::fabs(pos.X) + 1 > CellDimensions) {
            CellDimensions = std::abs(pos.X) + 1;
        }
        if (std::fabs(pos.Y) + 1 > CellDimensions) {
            CellDimensions = std::abs(pos.Y) + 1;
        }
    }

    Vertices2D.Empty();

	for(int i = 0; i < MembraneResolution; i++)
	{
		Vertices2D.Emplace(-CellDimensions + 2*CellDimensions/MembraneResolution*i,
            -CellDimensions);
	}
	for(int i = 0; i < MembraneResolution; i++)
	{
		Vertices2D.Emplace(CellDimensions,
            -CellDimensions + 2*CellDimensions/MembraneResolution*i);
	}
	for(int i = 0; i < MembraneResolution; i++)
	{
		Vertices2D.Emplace(CellDimensions - 2*CellDimensions/MembraneResolution*i,
            CellDimensions);
	}
	for(int i = 0; i < MembraneResolution; i++)
	{
		Vertices2D.Emplace(-CellDimensions,
            CellDimensions - 2*CellDimensions/MembraneResolution*i);
	}

	for(int i = 0; i < 50*CellDimensions; i++)
    {
        DrawMembrane();
    }
}
    
void UMembraneComponent::DrawMembrane(){

    // Stores the temporary positions of the membrane.
	TArray<FVector2D> NewPositions = Vertices2D;

    // Loops through all the points in the membrane and relocates them as necessary.
	for(size_t i = 0, end = NewPositions.Num(); i < end; i++)
	{
		const auto ClosestOrganelle = FindClosestOrganelles(Vertices2D[i]);
        
		if(!std::get<1>(ClosestOrganelle))
		{
			NewPositions[i] = (Vertices2D[(end+i-1)%end] + Vertices2D[(i+1)%end])/2;
		}
		else
		{
			const auto movementDirection = GetMovement(Vertices2D[i],
                std::get<0>(ClosestOrganelle));
            
			NewPositions[i].X -= movementDirection.X;
			NewPositions[i].Y -= movementDirection.Y;
		}
	}

	// Allows for the addition and deletion of points in the membrane.
	for(size_t i = 0; i < NewPositions.Num() - 1; i++)
	{
		// Check to see if the gap between two points in the membrane is too big.
		if(FVector2D::Distance(NewPositions[i], NewPositions[(i+1)%NewPositions.Num()]) >
            CellDimensions/MembraneResolution)
		{
			// Add an element after the ith term that is the average of the i and i+1 term.
			const auto tempPoint = (NewPositions[(i + 1) % NewPositions.Num()] +
                NewPositions[i])/2;
            
			NewPositions.Insert(tempPoint, i+1);

			i++;
		}

		// Check to see if the gap between two points in the membrane is too small.
		if(FVector2D::Distance(NewPositions[(i+1)%NewPositions.Num()], (NewPositions[(i-1) %
                        NewPositions.Num()])) < CellDimensions/MembraneResolution)
		{
			// Delete the ith term.
			NewPositions.RemoveAt(i);
		}
	}

	Vertices2D = NewPositions;    
}

void UMembraneComponent::MakePrism(){

    const double Height = .1;

    MeshPoints.Empty();

	for(size_t i = 0, end = Vertices2D.Num(); i < end; i++)
	{
		MeshPoints.Emplace(Vertices2D[i%end].X, Vertices2D[i%end].Y,
            +Height/2);
        
		MeshPoints.Emplace(Vertices2D[(i+1)%end].X, Vertices2D[(i+1)%end].Y,
            -Height/2);
        
		MeshPoints.Emplace(Vertices2D[i%end].X, Vertices2D[i%end].Y,
            -Height/2);
        
		MeshPoints.Emplace(Vertices2D[i%end].X, Vertices2D[i%end].Y,
            +Height/2);
        
		MeshPoints.Emplace(Vertices2D[(i+1)%end].X, Vertices2D[(i+1)%end].Y,
            +Height/2);
        
		MeshPoints.Emplace(Vertices2D[(i+1)%end].X, Vertices2D[(i+1)%end].Y,
            -Height/2);
	}

	for(size_t i = 0, end = Vertices2D.Num(); i < end; i++)
	{
		MeshPoints.Emplace(Vertices2D[i%end].X, Vertices2D[i%end].Y,
            +Height/2);
        
		MeshPoints.Emplace(0,0,Height/2);
        
		MeshPoints.Emplace(Vertices2D[(i+1)%end].X, Vertices2D[(i+1)%end].Y,
            +Height/2);

		MeshPoints.Emplace(Vertices2D[i%end].X, Vertices2D[i%end].Y,
            -Height/2);
        
		MeshPoints.Emplace(Vertices2D[(i+1)%end].X, Vertices2D[(i+1)%end].Y,
            -Height/2);
        
		MeshPoints.Emplace(0,0,-Height/2);
	}
}

void UMembraneComponent::CalcUVCircle(){

    UVs.Empty();

    for(size_t i = 0, end = MeshPoints.Num(); i < end; i++)
    {
        double x, y, z, a, b, c;
        x = MeshPoints[i].X;
        y = MeshPoints[i].Y;
        z = MeshPoints[i].Z;

        double ray = x*x + y*y + z*z;

        double t = std::sqrt(ray)/(2.0*ray);
        a = t*x;
        b = t*y;
        c = t*z;

        UVs.Emplace(a+0.5,b+0.5// ,c+0.5
        );
    }
}

// ------------------------------------ //
std::tuple<FVector2D, bool> UMembraneComponent::FindClosestOrganelles(FVector2D Target){
    
    // The distance we want the membrane to be from the organelles squared.
	double closestSoFar = 4;
	int closestIndex = -1;

	for (size_t i = 0, end = OrganellePositions.Num(); i < end; i++)
	{
		double lenToObject =  FVector2D::DistSquared(Target, OrganellePositions[i]);

		if(lenToObject < 4 && lenToObject < closestSoFar)
		{
			closestSoFar = lenToObject;

			closestIndex = i;
		}
	}

	if(closestIndex != -1)
		return std::make_tuple(OrganellePositions[closestIndex], true);
	else
		return std::make_tuple(FVector2D(0, 0), false);
    
}

FVector2D UMembraneComponent::GetMovement(FVector2D Target, FVector2D ClosestOrganelle){

    double power = pow(2.7, FVector2D::Distance(-Target, ClosestOrganelle)/10)/50;

	return (ClosestOrganelle - Target)*power;
}

